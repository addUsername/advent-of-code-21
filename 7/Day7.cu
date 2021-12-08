#include <unistd.h>
#include <sys/mman.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define NUMBER_CRABS 1000

int readFileAsStrings(char* filename, char* lines);
void check(cudaError_t err, char *mssg);

__global__ void findLower(int* count, int len){

    int position = -1;
    int min = INT_MAX;
        for(int i=0;i<len-1;i++){
            if(count[i] < min){
                min = count[i];
                position = i;
            }
        }
    printf("\nbest pos=%d, min=%d\n",position, min);
    
}
__global__ void getSum(int crabs[], int* count){

    //printf("\n t %d | block %d | dim %d",threadIdx.x,blockIdx.x,blockDim.x);
    
    int idxStart = 100 * threadIdx.x;
    int idxFinish = idxStart + 100;
    int position = blockIdx.x;
    int incr = 0;
   // printf("\n%d idxS | idxF %d \n",idxStart,idxFinish);
    
    int a = 0;
    for(int i = idxStart; i < idxFinish; i++){

        a = position - crabs[i];
        incr +=  (a > 0)? a : -1*a;
      //  printf("\n%d a | incr %d \n",a,incr);
    }  
     __syncthreads();
    atomicAdd(&count[position],incr);
    //printf("%d crabs[position] | count %d |  | incr %d\n",crabs[idxStart], count[position],incr);
    __syncthreads();

}

int main() {
    char *lines;
    //-----------------Read file-----------------------------------------------
    lines = (char*) malloc(NUMBER_CRABS*4); // NUMBER OF FISH
    int lenLine = readFileAsStrings("input.txt", lines);
    //-----------------Parse text----------------------------------------------    
    int crabs[NUMBER_CRABS];
    int len = 0;
    int max = 0;
    char* aux = strtok(lines, ",");
    
    while(true){
 
        if (aux  == NULL) {
            break;
        }        
        crabs[len] = atoi(aux);
        max = (max < crabs[len])? crabs[len]: max;
        len++;
        aux = strtok(NULL, ",");
    }
    free(lines);
    //-----------------Malloc input--------------------------------------------
    int* d_lines;
    check( cudaMalloc((int**)&d_lines, len * sizeof(int)), "&d_lines");
    check( cudaMemcpy(d_lines, crabs, len * sizeof(int), cudaMemcpyHostToDevice ), "d_lines");

    //-----------------Atomic operation---------------------------------------
    int *d_count;
    check( cudaMalloc( (void **)&d_count, max*sizeof(float)),"d_count" );
    check( cudaMemset(d_count, 0, max*sizeof(float)), "count");
        
    getSum<<<max,NUMBER_CRABS/100>>>(d_lines, d_count);
    cudaDeviceSynchronize();
    findLower<<<1,1>>>(d_count,max);

    cudaFree(d_lines);
    cudaDeviceSynchronize();
    cudaFree(d_count);
    return 0;
}

void check(cudaError_t err, char* mssg){
    if (err != 0) {
        printf("error copying/malloc :%s\n", mssg);
        printf("%s",cudaGetErrorString(err));
        exit(err);           
    }
}

int readFileAsStrings(char* filename, char* lines){
 	FILE *fp;
	size_t len = 0;
    char *line = NULL;
    ssize_t read;
    int i = 0;
    fp = fopen(filename, "r");
    
    if (fp == NULL)
        exit(EXIT_FAILURE);
    
        read = getline(&line, &len, fp);
       
        if (read == -1 || strlen(line) < 2){
            exit(EXIT_FAILURE);
        }
        strcpy(lines, line);
        
    return strlen(line);
}