#include <unistd.h>
#include <sys/mman.h>   /* For open(), creat()   */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>


// this process just one board, so there is a gpu thread per board
__global__ void bingo(int * numbers[], int ** boards, int numbersMaxLength, int LINE_LENGTH, bool Ans1){

    
    __shared__ int shared;
    
    int idxStart = threadIdx.x * 5;
    int idxFinish = idxStart + 5;
    int numOfAppearsLine[] = {0,0,0,0,0};
    int numOfAppearsColumn[] = {0,0,0,0,0};
    int round = 0;
    int sum = 0;
    int count = 0;
    
    /*
    if(threadIdx.x > 1 ){
        return;
    }
    */
     // Yep, we repeat 1st for bucle adding 1 iteration till round == numbersMaxLength
     // for num in nums
    while(round < numbersMaxLength){
            // For board line
            for(int i = idxStart; i < idxFinish; i++){
                // for num in line
                for (int k = 0; k <LINE_LENGTH; k++){
                    // Pre calc sum (calculate this for all threads is not cool but)
                    if (round == 0) {
                        sum += boards[i][k];
                    }
                    if( boards[i][k] == *numbers[round]){
                        sum -= boards[i][k];

                       numOfAppearsLine[k] = numOfAppearsLine[k]+1;
                       numOfAppearsColumn[i-idxStart] = numOfAppearsColumn[i-idxStart]+1;
                        if(numOfAppearsLine[k] == 5 ||  numOfAppearsColumn[i-idxStart] == 5 ){
                            printf("bingo!!");
                            printf("\n\n %d",*numbers[round]*sum);
                            shared = *numbers[round]*sum;
                            /*
                            if(Ans1){
                                printf("\nBingoo!");
                                printf("\nnumber: %d",*numbers[round]);
                                printf("\nboard: %d", threadIdx.x);
                                printf("\nline :%d",i-idxStart);


                                printf("\n\n %d",*numbers[round]*sum);
                            }*/
                            return;
                        }                        
                    }
                    __syncthreads();
                    // If Ans 2 just keep going
                    if(Ans1 && shared != NULL){
                        return;
                    }
                }
                __syncthreads();        
            }
        // Add new num and restart all
        round++;
    }
    printf("\nNo Bingo??");
    // last bingoed
    printf("\n %d",shared);
    __syncthreads();
    
}

int main() {

    
    bool const Ans1 = true;
    int const LENGTH_ROW = 5;
    int NUMBERS_COUNT = 0;
    int NUMBER_ROWS = 0;
    int NUMBER_OF_BOARDS = 5 / LENGTH_ROW;
    cudaError_t err;

    //---------------READING FILE----------------
 	FILE *fp;
	size_t len = 0;
    char *line = NULL;
    ssize_t read;
    // use dos2unix as default, win files text destroy this silently
    fp = fopen("input.txt", "r");
    
    if (fp == NULL)
        exit(EXIT_FAILURE);
    char *b[1000];
    int i = 0;
    // Getting strings from file
    while (true){
        read = getline(&line, &len, fp);
       
        if (read == -1){
            break;
        }        
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
    printf("%d",i);
    NUMBER_ROWS = i;
    NUMBER_OF_BOARDS = i / 5;
    
    fclose(fp);
    if (line){
		free(line);
	}
    //---------------GETTING NUMBERS----------------
    int numbers[100]; // I see the future
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
    int boards[NUMBER_ROWS][5];
    int aux[5];
    for (int j=0; j < NUMBER_ROWS-1; j++){
        ptr = strtok(b[j+1], " ");
        if(ptr == NULL){
                break;
        }

        for ( i = 0; i<5; i++){

            boards[j][i] = atoi(ptr);
            ptr = strtok(NULL, " ");
        }
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
    bingo<<< 1, NUMBER_OF_BOARDS>>>(_totalNumbers, _total,NUMBERS_COUNT, LENGTH_ROW, Ans1 );
    cudaDeviceSynchronize();
 
    cudaDeviceReset();
    cudaDeviceSynchronize();
    
    return 0;
}
