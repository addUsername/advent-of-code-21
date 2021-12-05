#include <unistd.h>
#include <sys/mman.h>   /* For open(), creat()   */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "cuda_runtime.h"

__global__ void cuda_hello(char ** b, char* deviceOutput ){

    int NUMBER_ROWS = 1001;
    int sum = 0;

    for (int i = 0; i < NUMBER_ROWS - 1; i++){
        
        if( b[i][threadIdx.x] == '1'){
            sum++;
        }        
    }
    if (sum >= NUMBER_ROWS/2){
        deviceOutput[threadIdx.x] = '1';
    }else{        
        deviceOutput[threadIdx.x] = '0';
    }
    __syncthreads();        
}

//This makes no sense bc just one thread is needed but for practice purposes it's ok
__global__ void getOxigen(char ** b, char* deviceOutput, char* oxi){

    const int NUMBER_ROWS = 1001;
    int LENGHT_ROW = 12+1;

    char *sorted[NUMBER_ROWS];
    int size = NUMBER_ROWS;
    int index = 0;


    for (int i = 0; i < LENGHT_ROW ; i++){
        for (int j = 0; j < size- 1; j++){

            if(i == 0){                
                if(b[j][0] == deviceOutput[0] ){
                    sorted[index] = (char*) malloc(LENGHT_ROW);                
                    sorted[index] = b[j];
                    index++;
                }
            }else{
                if(sorted[j][i] == deviceOutput[i] ){              
                    sorted[index] = sorted[j];
                    index++;
                    
                }
            }
        }
        size = index;
        index = 0;       
    }
    //strcpy doesn't work here
    for(int k = 0; k<LENGHT_ROW; k++){
        oxi[k] = sorted[0][k];
    }    
    __syncthreads();        
}

__global__ void getC02(char ** b, char* deviceOutput, char* co2){

    const int NUMBER_ROWS = 1001;
    int LENGHT_ROW = 12+1;

    char *sorted[NUMBER_ROWS];
    int size = NUMBER_ROWS;
    int index = 0;

    for (int i = 0; i < LENGHT_ROW ; i++){
        for (int j = 0; j < size- 1; j++){

            if(i == 0){                
                if(b[j][0] != deviceOutput[0] ){
                    sorted[index] = (char*) malloc(LENGHT_ROW);                
                    sorted[index] = b[j];
                    index++;
                }
            }else{
                if(sorted[j][i] == deviceOutput[i] ){                
                    sorted[index] = sorted[j];
                    index++;
                    
                }
            }
        }       
        size = index;
        index = 0;       
    }
    //strcpy doesn't work here    
    for(int k = 0; k<LENGHT_ROW; k++){
        co2[k] = sorted[0][k];
    }
    __syncthreads();        
}

int main() {

    int NUMBER_ROWS = 1001;
    int LENGHT_ROW = 12+1;


 	FILE * fp;
	size_t len = 0;
    char *line = NULL;
    ssize_t read;

    fp = fopen("input.txt", "r");
    if (fp == NULL)
        exit(EXIT_FAILURE);	

    
	// this is an array of pointers or String[]
    // if you want to acces to its values cast (char **) b[i]
	// https://stackoverflow.com/a/8824682/13771772
    char *b[NUMBER_ROWS];

    int i = 0;
    // Getting strings from file
    while ((read = getline(&line, &len, fp)) != -1) {

        // get mem for each string an store its pointer
        b[i] = (char*) malloc(LENGHT_ROW);        
        if (b[i]  == NULL) {
            printf("unable to allocate memory \n");
            return -1;
        }

        //get rid off /n by finishing the line wit thst char.. but i think we are storing the \n and null char, and that's not good
        line[LENGHT_ROW-2] = '\0';
        strcpy(b[i], line);
        i++;
	}
    
    fclose(fp);
    if (line){
		free(line);
	}

    // https://forums.developer.nvidia.com/t/is-copying-an-array-of-character-strings-to-device-memory-absolutely-impossible/17273/11
    // What we want to do is to make our *b[] (aka String[]) visible on device(gpu)
    // This shit is not trivial.
    // cudaMempcy or memcpy doesn't do any kind of "deep copying" so, we need to iterate (over *b[]) to allocate and
    // copy each string, while storing its device adresses in a host array (* ptrDevice[]), then copy this array from host memory into device memory.

    // This holds ptr addresses from device (gpu)    
    char *ptrDevice[NUMBER_ROWS];
    // This is the argument for the cuda func
    char **_total;

    for (int i = 0; i< NUMBER_ROWS -1; i++){

        // malloc 13 chars size and store its "device" pointer to our host ptrDevice
        cudaError_t err = cudaMalloc((void **)&ptrDevice[i], LENGHT_ROW);
        // _________________________________^_^
        if (err != 0) {
            printf("error allocating");
            printf("%s",cudaGetErrorString(err));
            return -1;            
        }
    
        // Then we copy strings from *b[] in the gpu address allocated before
        err = cudaMemcpy(ptrDevice[i], b[i], LENGHT_ROW, cudaMemcpyHostToDevice);
        if (err != 0) {
            printf("error copying ptrDevice[i] ");
            printf("%s",cudaGetErrorString(err));
            return -1;            
        }
        
    }
    // Once done, we need to allocate space for the array with 1000 gpu address.
    cudaMalloc((void ***)&_total, LENGHT_ROW*NUMBER_ROWS*sizeof(char));
    // ______________^___^

    // And copy to device
    cudaError_t err = cudaMemcpy(_total, ptrDevice, LENGHT_ROW*NUMBER_ROWS*sizeof(char), cudaMemcpyHostToDevice);
    if (err != 0) {
            printf("error copying _total");
            printf("%s",cudaGetErrorString(err));
            return -1;            
        }
        
    char* deviceOutput;
    
    err = cudaMalloc((char**) &deviceOutput,LENGHT_ROW * sizeof(char));
    if (err != 0) {
            printf("error allocating");
            printf("%s",cudaGetErrorString(err));
            return -1;            
    }

    // Ok Now we are ready to call cuda, we want 1 block of 13 threads bc yes
	// threads < blocks < grid
    // https://gist.github.com/dpiponi/1502434
    // https://developer.nvidia.com/blog/easy-introduction-cuda-c-and-c/
	cuda_hello<<<1,LENGHT_ROW-1>>>(_total, deviceOutput);

    // This waits for gpu threads to finish
    cudaDeviceSynchronize();

    // Here we need to get the output..
    char* gamma = (char*) malloc(LENGHT_ROW);

    //an illegal memory access was encountered
    err = cudaMemcpy(gamma, deviceOutput, LENGHT_ROW, cudaMemcpyDeviceToHost);
    if (err != 0) {
            printf("error copying gamma ");
            printf("%s",cudaGetErrorString(err));
            return -1;            
        }

    char* epsilon = (char*) malloc(LENGHT_ROW);
    for (int i =0; i< LENGHT_ROW -1; i++){
        if(gamma[i] == '1'){
            epsilon[i] = '0';
        }else{
            epsilon[i] = '1';
        }
    }

    printf("\n%s", gamma);                  //Should be 001100001011
    printf("\n%d", strtol(gamma,NULL,2));   //Should be 779 
    printf("\n%s", epsilon);                //Should be 110011110100
    printf("\n%d", strtol(epsilon,NULL,2)); //Should be 3316

    // I really dont know why i have to do gamma+1 and epsilon-1, some binary shit i hope
    printf("\n %ld", (1 + strtol(gamma,NULL,2)) * ( -1 + strtol(epsilon,NULL,2))); //Should be 2583164


    printf("\nSECOND EX");
    char * oxigenDevice;
    err = cudaMalloc((void **)&oxigenDevice, LENGHT_ROW);
    // _____________________^_^
    if (err != 0) {
        printf("error allocating");
        printf("%s",cudaGetErrorString(err));
        return -1;            
    }

    getOxigen<<<1,1>>>(_total, deviceOutput, oxigenDevice);
    cudaDeviceSynchronize();
    
    char * oxigen = (char*) malloc(LENGHT_ROW);
    err = cudaMemcpy(oxigen, oxigenDevice, LENGHT_ROW, cudaMemcpyDeviceToHost);
    if (err != 0) {
            printf("error copying oxi ");
            printf("%s",cudaGetErrorString(err));
            return -1;            
    }
    printf("\n oxigen -> ");
    printf("%s",oxigen);
    printf("\n%ld",strtol(oxigen,NULL,2));
    
    char * co2Device;
    err = cudaMalloc((void **)&co2Device, LENGHT_ROW);
    // _____________________^_^
    if (err != 0) {
        printf("error allocating");
        printf("%s",cudaGetErrorString(err));
        return -1;
    }
    getC02<<<1,1>>>(_total, deviceOutput, co2Device);
    cudaDeviceSynchronize();

    char * co2 = (char*) malloc(LENGHT_ROW);
    err = cudaMemcpy(co2, co2Device, LENGHT_ROW, cudaMemcpyDeviceToHost);
    if (err != 0) {
            printf("error copying co2 ");
            printf("%s",cudaGetErrorString(err));
            return -1;            
    }
    printf("\n c02 -> ");
    printf("%s",co2);    
    printf("\n%ld",strtol(co2,NULL,2) );

    printf("\n %ld",(1+strtol(oxigen,NULL,2)) * (-1+strtol(co2,NULL,2)));
    // check for null before..
    /*
    cudaFree(ptrDevice);
    cudaFree(_total);
    cudaFree(deviceOutput);
    */
    cudaDeviceReset();
    cudaDeviceSynchronize();    
    
    return 0;	
}
