#include <unistd.h>
#include <sys/mman.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

#define L 10
#define STEPS 100

int readFileAsStrings(char* filename, char* lines[]);
void check(cudaError_t err, char *mssg);

__device__ int sum; // var defined in __device__ persists between kernel calls
__shared__ bool flag; // this thing resets

__global__ void doStep(int* d_in){

    
    int idx = threadIdx.x;
    int row = idx / L;
    if(idx == 0) flag = true;
    __syncthreads();    // play with this sync here, it varies the output by a lot

    bool t_flag = false;

    //if (idx != 11) return;
    d_in[idx]++;

    while(flag){

        // i know.. check how others had implemented it
        if(d_in[idx] > 9 && !t_flag){
            //printf("%d ->\n",idx);
            t_flag = true;
            atomicAdd(&sum,1);

            if ( (idx-1)/L == row){
                atomicAdd( &d_in[idx-1],1);
            }        
            if ( (idx+1)/L == row) atomicAdd(&d_in[idx+1],1);
            
            if (idx-L>-1 && (idx-L)/L == row-1 ) atomicAdd(&d_in[idx-L],1);

            if (idx-L+1>-1 && (idx-L+1)/L == row-1 ) atomicAdd(&d_in[idx-L+1],1);

            if (idx-L-1>-1 && (idx-L-1)/L == row-1 ) atomicAdd(&d_in[idx-L-1],1);

            if (idx+L<L*L && (idx+L)/L == row+1) atomicAdd(&d_in[idx+L],1);

            if (idx+L+1<L*L  && (idx+L+1)/L == row+1) atomicAdd(&d_in[idx+L+1],1);

            if (idx+L-1<L*L  && (idx+L-1)/L == row+1) atomicAdd(&d_in[idx+L-1],1);

            
        }
        if(idx == 0) flag = false;
        __syncthreads();
        if(d_in[idx] > 9 && !t_flag){
            flag = true;
        }
        __syncthreads();

        //if(idx == 0) printf("\n 1 more\n");
    }
    if(t_flag) d_in[idx] = 0;
}

__global__ void show(int* d_in){

    for (int i = 0; i<L; i++){
        for (int j = 0; j<L; j++){

            printf("%d", d_in[i*L+j]);
        }
        printf("\n");
    }
    printf("\n sum: %d\n",sum);
}
 

int main() {
    //-----------------Read file-----------------------------------------------    
    char *lines[L];
    int lenLine = readFileAsStrings("input.txt", lines);

    //---------------itoa()-------------------------------------------------
    // today we go with char, bc we just store 1-9 individually NOPE, atomic ops only work for 32-64 bits, char are not.
    // and it's pretty difficult to implement, you have to do like 2 ops a the same time to not fucked it up
    int *d_in;
    int *h_in = (int*) malloc(L*L*sizeof(int));

    //flattening
    for (int i = 0; i<L; i++){
        for (int j = 0; j<L; j++){
            char string_for_atoi[2] = { lines[i][j], '\0' };
            h_in[i*L+j] = atoi(string_for_atoi);
        }
    }

    check( cudaMalloc((int**)&d_in, L*L*sizeof(int)),"&d_in");
    check( cudaMemcpy(d_in, h_in, L*L*sizeof(int), cudaMemcpyHostToDevice),"d_in");
    free(h_in);
    //----------------run()-----------------------------------
    clock_t begin = clock();
   
    for(int i =0; i<STEPS; i++){
        doStep<<<1,L*L>>>(d_in);
        cudaDeviceSynchronize();
    }
    
    show<<<1,1>>>(d_in);
    cudaDeviceSynchronize();
        
    clock_t end = clock();
    printf("\nThe elapsed time is %f seconds", (double)(end - begin) / CLOCKS_PER_SEC);       
        
    cudaFree(d_in);
    cudaDeviceReset();

    return 0;
}

void check(cudaError_t err, char* mssg){
    if (err != 0) {
        printf("error copying/malloc :%s\n", mssg);
        printf("%s",cudaGetErrorString(err));
        exit(err);           
    }
}

int readFileAsStrings(char* filename, char* lines[L]){
    
    FILE *fp;
	size_t len = 0;
    char *line = NULL;
    ssize_t read;
    
    fp = fopen(filename, "r");
    
    if (fp == NULL)
        exit(EXIT_FAILURE);
    
    int i=0;
    while( i<L ){
        read = getline(&line, &len, fp);
        if (read == -1 ){
            printf("exit");
            exit(EXIT_FAILURE);
        }
        if ( strlen(line) < 2){
            continue;
        }
        lines[i] = (char*) malloc(L*sizeof(char)+1);
        strcpy(lines[i], line);

        //Ugly but..
        strtok(lines[i],"\n");
        i++;
    }
    
    return i;
}