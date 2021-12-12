#include <unistd.h>
#include <sys/mman.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>       // for clock_t, clock(), CLOCKS_PER_SEC

/* aaaa
  b    c
  b    c  
   dddd 
  e    f
  e    f
   gggg */

#define NUMBER_IN 200 //10
#define LO 4 //# of digits for the output
#define LI 10
#define ANS1 true


int readFileAsStrings(char* filename, char* lines[]);
void check(cudaError_t err, char *mssg);


// Get len str
__device__ int len(char* str){

    for (int i =0; i< 10; i++){

        if(str[i] == '\0'){
            return i;
        }
    }
    return NULL;
}
// Returns how many chars from string 1 are present in 2
__device__ int numCoincidences(char* knowStr, char* uknowStr){

    int sum = 0;

    for (int i = 0; i< len(knowStr); i++){
        for (int j =0; j< len(uknowStr); j++){
            
            if (knowStr[i] == uknowStr[j]){
                sum = sum +1;
                break;
            }
        }
    }
    return sum;
}
// Just in this case it's usefull to get the char value from 8 that is not present in 9
__device__ char* specialCaseLen5(char* knowStr, char* uknowStr){


    bool coincidence = false;
    char *toReturn = (char*) malloc(sizeof(char)*2 );
    toReturn[1] = '\0';
    for (int i =0; i< len(knowStr); i++){
        coincidence = false;
        for (int j =0; j< len(uknowStr); j++){
            if (knowStr[i] == uknowStr[j]){
                
                coincidence = true;
            }
        }
        if (!coincidence){
            toReturn[0] = knowStr[i];
            return toReturn;
        }
    }
    return NULL;
}
// Compare 2 strings, order doesn't matter ab == ba
__device__ bool strcmp(char *s1, char *s2){
    
    if(len(s1) != len(s2)){
        return false;
    }

    if(numCoincidences(s1,s2) == len(s1)){
        return true;
    }
    return false;
}
// This func orders array input, position indicates number value
__global__ void getSum(char* d_in){

    int idx = threadIdx.x;
    char* aux = (char*) malloc(sizeof(char)*10*NUMBER_IN);
    
    for(int i = 0; i<(LI); i++){

        //1
        if (len ( d_in+((LO+LI)*idx + i)*10 ) == 2){
            memcpy( aux+(1*10), d_in+((LO+LI)*idx + i)*10,sizeof(char)*10);
        }
        //7
        if (len ( d_in+((LO+LI)*idx + i)*10 ) == 3){
            memcpy( aux+(7*10), d_in+((LO+LI)*idx + i)*10,sizeof(char)*10);
        }
        //4
        if (len ( d_in+((LO+LI)*idx + i)*10 ) == 4){
            memcpy( aux+(4*10), d_in+((LO+LI)*idx + i)*10,sizeof(char)*10);
        }
        //8
        if (len ( d_in+((LO+LI)*idx + i)*10 ) == 7){
            memcpy( aux+(8*10), d_in+((LO+LI)*idx + i)*10,sizeof(char)*10);
        }        
    }
    for(int i = 0; i<(LI); i++){

        //0, 9, 6
        if (len ( d_in+((LO+LI)*idx + i)*10 ) == 6){
            
            if ( numCoincidences(aux+(7*10),d_in+((LO+LI)*idx + i)*10) == 2){
                // 6
                memcpy( aux+(6*10), d_in+((LO+LI)*idx + i)*10,sizeof(char)*10);

            }else if ( numCoincidences(aux+(4*10),d_in+((LO+LI)*idx + i)*10) == 4){
                // 9
                memcpy( aux+(9*10), d_in+((LO+LI)*idx + i)*10,sizeof(char)*10);
            }else{
                // 0
                memcpy( aux+(0*10), d_in+((LO+LI)*idx + i)*10,sizeof(char)*10);
            }
        }
        
    }

    for(int i = 0; i<(LI); i++){

         // 2, 3, 5
        if (len ( d_in+((LO+LI)*idx + i)*10 ) == 5){
            if ( numCoincidences(aux+(1*10),d_in+((LO+LI)*idx + i)*10) == 2){
                // 3
                memcpy( aux+(3*10), d_in+((LO+LI)*idx + i)*10,sizeof(char)*10);
            }else {
                char* charWhoHas2butNot9 = specialCaseLen5(aux+(8*10), aux+(9*10));

                if ( numCoincidences(charWhoHas2butNot9,d_in+((LO+LI)*idx + i)*10) == 0){
                    // 5
                    memcpy( aux+(5*10), d_in+((LO+LI)*idx + i)*10,sizeof(char)*10);
                }else{
                    // 2
                    memcpy( aux+(2*10), d_in+((LO+LI)*idx + i)*10,sizeof(char)*10);
                }
            }
        }
    }

    for(int i = 0; i<(LI); i++){
        memcpy(  d_in+((LO+LI)*idx + i)*10, aux+(i*10),sizeof(char)*10);
    }
    return;
}

// by using the ordered input array get the output
__global__ void transcribe(char* d_in, int* d_out){

   
    int idx = threadIdx.x;
    
    for(int i = LI; i<(LO+LI); i++){
        for(int j = 0; j<(LI); j++){

            // gl, index are hard in a flattened array
            if ( strcmp(d_in+(((LO+LI)*idx + j)*10), d_in+(((LO+LI)*idx + i)*10))){
                atomicAdd(&d_out[j],1);
                break;
            }
        }
    }
}


int main() {
    //-----------------Read file-----------------------------------------------    
    char *lines[NUMBER_IN];
    
    int lenLine = readFileAsStrings("input.txt", lines);
    //-----------------Parse text----------------------------------------------
    // Next time this will be flat (1D) from the beginning   
    char *h_lines[NUMBER_IN][LO+LI];
    char* aux = (char*) malloc(10*sizeof(char));

    for (int i = 0; i<NUMBER_IN; i++ ){ 

        strcpy(aux, strtok(lines[i], " "));
        
        for (int j=0; j<(LO+LI); j++){ 
            h_lines[i][j] = (char*) malloc(10*sizeof(char));

            if(strlen(aux) > 1){                
                strcpy(h_lines[i][j], aux);
            }else{
                strcpy(aux, strtok(NULL, " "));
                strcpy(h_lines[i][j], aux);

            }
            if(j != LO+LI-1 ){
                strcpy(aux, strtok(NULL, " "));
            }
        }
    }

    //-----------------Malloc input--------------------------------------------
    // flattening, kinda cool trick but index become a little bit ugly
    char* d_in;
    char* h_in;
    h_in = (char *) malloc(NUMBER_IN*(LO+LI)*10*sizeof(char));

    for(int i = 0; i<NUMBER_IN; i++){
        for(int j= 0; j< (LO+LI); j++){
            memcpy(h_in+(10*(i*(LO+LI) + j)), h_lines[i][j], 10*sizeof(char));
         }            
    }
    check( cudaMalloc(&d_in,NUMBER_IN*(LO+LI)*10*sizeof(char) ),"&d_in");
    check( cudaMemcpy(d_in, h_in,NUMBER_IN*(LO+LI)*10*sizeof(char),cudaMemcpyHostToDevice),"h_in");

    free(h_in);

    clock_t begin = clock();

    //---------------Order asc input array---------------------------------------
    getSum<<<1,NUMBER_IN>>>(d_in);
    cudaDeviceSynchronize();

    //--------------Malloc output------------------------------------------------
    int* h_out = (int*) calloc(10,sizeof(int));
    int* d_out;
    check( cudaMalloc(&d_out,10*sizeof(int) ),"d_out");
    check( cudaMemcpy(d_out, h_out,10*sizeof(int),cudaMemcpyHostToDevice),"h_out");

    printf("\n trancribe()");

    // This can be improved, just one thread for value..
    transcribe<<<1,NUMBER_IN>>>(d_in, d_out);
    cudaDeviceSynchronize();
    
    check( cudaMemcpy(h_out, d_out,10*sizeof(int),cudaMemcpyDeviceToHost ),"h_out" );

    clock_t end = clock();

    for(int i = 0; i<10; i++){
        printf("%d ",h_out[i]);
    }
    printf("\nAns1 -> %d",h_out[1]+h_out[8]+h_out[7]+h_out[4]);

    printf("\nThe elapsed time is %f seconds", (double)(end - begin) / CLOCKS_PER_SEC);
    free(h_out);
    cudaFree(d_in);
    cudaFree(d_out);
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

int readFileAsStrings(char* filename, char* lines[NUMBER_IN]){
 	FILE *fp;
	size_t len = 0;
    char *line = NULL;
    ssize_t read;
    fp = fopen(filename, "r");
    
    if (fp == NULL)
        exit(EXIT_FAILURE);
    
    int i=0;
    while( i<NUMBER_IN ){

        read = getline(&line, &len, fp);
        if (read == -1 || strlen(line) < 2){
            exit(EXIT_FAILURE);
        }
        lines[i] = (char*) malloc(len*sizeof(char));
        strcpy(lines[i], line);

        //Ugly but..
        strtok(lines[i],"\n");
        i++;
    }
        
    return i;
}