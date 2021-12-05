#include <unistd.h>
#include <sys/mman.h>   /* For open(), creat()   */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "cuda_runtime.h"

__global__ void bingo(int * numbers[], int ** boards, int * finish, int numbersMaxLength, int LINE_LENGTH){

    __shared__ int shared;
    // printf("\n thread %d\n", threadIdx.x);
    int idxStart = (threadIdx.x * 5);
    int idxFinish = idxStart + 5;
    int numOfAppears = 0;
    int round = 5;
    int * line[5];
    int count = 0;

    if(0 != threadIdx.x ){
        return;
    }
     // Yep, we repeat 1º for bucle adding 1 iteration till round == numbersMaxLength
    while(round < numbersMaxLength){

        for(int j=round; j<=round ;j++ ){
            for(int i = idxStart; i < idxFinish; i++){
                //line = boards[i];
                for (int k = 0; k <LINE_LENGTH; k++){
                    
                    printf("  %d ", &boards[i][j]);
                    //printf(" %d",*numbers[k]);
                    
                    // Here i should check if number exists in row
                }
                printf("\n");
                //
            }
            printf("\nNumber -> :");
            
            return;
        }
        round++;
    }
    
    

    
    if(threadIdx.x == 1){
        shared = threadIdx.x;
        *finish = threadIdx.x;
        return;
    }
    __syncthreads();
    if(shared != NULL){
        //printf("return from thread: %d", threadIdx.x);
        return;
    }
}

int main() {

    int const NUMBER_OF_BOARDS = 3;
    int const LENGTH_ROW = 15;
    int NUMBERS_COUNT = 0; //??
    int NUMBER_ROWS = 0;   //??
    cudaError_t err;

    //---------------READING FILE----------------
 	FILE * fp;
	size_t len = 0;
    char *line = NULL;
    ssize_t read;

    fp = fopen("input.txt", "r");
    
    if (fp == NULL)
        exit(EXIT_FAILURE);	
    
    char *b[1000];
    int i = 0;
    // Getting strings from file
    while ((read = getline(&line, &len, fp)) != -1) {

        // get mem for each string an store its pointer
        if(strlen(line) < 2){
            continue;
        }
        b[i] = (char*) malloc(strlen(line));        
        if (b[i]  == NULL) {
            printf("unable to allocate memory \n");
            return -1;
        }
        strcpy(b[i], line);
        i++;
	}
    NUMBER_ROWS = i;
    
    fclose(fp);
    if (line){
		free(line);
	}
    
    //---------------GETTING NUMBERS----------------
    int numbers[100];
	int init_size = strlen(b[0]);
	char *ptr = strtok(b[0], ",");

    int j = 0;
    for(j = 0; true; j++){        
        if(ptr == NULL){
            break;
        }
        numbers[j] = atoi(ptr);
        ptr = strtok(NULL, ",");
    }
    NUMBERS_COUNT = j;
    //---------------MALLOC NUMBERS----------------  
    int *ptrNumbers[NUMBERS_COUNT];
    int **_totalNumbers;
    for (int i = 0; i< NUMBERS_COUNT-1; i++){

        err = cudaMalloc((void **)&ptrNumbers[i], sizeof(int));
        if (err != 0) {
            printf("error allocating");
            printf("%s",cudaGetErrorString(err));
            return -1;            
        }
                                        // ???
        err = cudaMemcpy(ptrNumbers[i], &numbers[i], sizeof(int), cudaMemcpyHostToDevice);
        if (err != 0) {
            printf("error copying ptrDevice[i] ");
            printf("%s",cudaGetErrorString(err));
            return -1;            
        }        
    }
    
    cudaMalloc((void ***)&_totalNumbers, NUMBERS_COUNT*sizeof(int));
    err = cudaMemcpy(_totalNumbers, ptrNumbers,  NUMBERS_COUNT*sizeof(int), cudaMemcpyHostToDevice);
    if (err != 0) {
            printf("error copying _totalNumbers");
            printf("%s",cudaGetErrorString(err));
            return -1;            
    }
    //---------------GETTING BOARD-----------------
    int *boards[NUMBER_ROWS];
    int aux[5];
    for (int j=0; j < NUMBER_ROWS-1; j++){
        ptr = strtok(b[j+1], " ");
        if(ptr == NULL){
                break;
        }
        boards[j] = (int*) malloc(5*sizeof(int));
        for ( i = 0; i<5; i++){

            memcpy(*boards[j][i], atoi(ptr), 5*sizeof(int));
        }
        
        
       //printf("%d", &boards[0][0]);
    }
    
    //---------------MALLOC BOARDS----------------
    int *ptrDevice[NUMBER_ROWS];
    int **_total;
    for (int i = 0; i< NUMBER_ROWS-1; i++){

        err = cudaMalloc((void **)&ptrDevice[i], LENGTH_ROW * sizeof(int));
        if (err != 0) {
            printf("error allocating");
            printf("%s",cudaGetErrorString(err));
            return -1;            
        }
    
        err = cudaMemcpy(ptrDevice[i], &boards[i], LENGTH_ROW * sizeof(int), cudaMemcpyHostToDevice);
        if (err != 0) {
            printf("error copying ptrDevice[i] ");
            printf("%s",cudaGetErrorString(err));
            return -1;            
        }        
    }
    cudaMalloc((void ***)&_total, LENGTH_ROW*NUMBER_ROWS*sizeof(int));
    err = cudaMemcpy(_total, ptrDevice, LENGTH_ROW*NUMBER_ROWS*sizeof(char), cudaMemcpyHostToDevice);
    if (err != 0) {
            printf("error copying _total");
            printf("%s",cudaGetErrorString(err));
            return -1;
    }
    //---------------MALLOC BINGO-----------------
    // if set, its value marks which thread has made bingo
    int* threadBingo;
    err = cudaMalloc((void**)&threadBingo, sizeof( int));
    if (err != 0) {
            printf("error allocating threadBingo");
            printf("%s",cudaGetErrorString(err));
            return -1;            
    }

    //---------------CALL DEVICE-----------------
    bingo<<<1,NUMBER_OF_BOARDS>>>(_totalNumbers, _total, threadBingo, NUMBERS_COUNT, LENGTH_ROW );
    cudaDeviceSynchronize();

    int* threadWhoMadeBingo = (int *) malloc(sizeof(int));
    /*
    err = cudaMemcpy(threadWhoMadeBingo, threadBingo, sizeof(int), cudaMemcpyDeviceToHost);
    if (err != 0) {
            printf("error copying co2 ");
            printf("%s",cudaGetErrorString(err));
            return -1;
    }
    printf("\n thread who made bingo %d", *threadWhoMadeBingo);
    */
    
    cudaDeviceReset();
    cudaDeviceSynchronize();
    
    return 0;
}
