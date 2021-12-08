#include <unistd.h>
#include <sys/mman.h>   /* For open(), creat()   */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define NUMBER_OF_DAYS 9
#define TWO 2

int readFileAsStrings(char* filename, char* lines);
void check(cudaError_t err);

__global__ void drawMoves(char * input, int length, int** output){

    int a = (int) input[0];

    int const day = threadIdx.x;
    int const ascciValue = 48 + threadIdx.x;
    output[day][0] = day;
    output[day][1] = 0;

    for (int i = 0; i <length; i++){
        if ((int) input[i] == ascciValue){
            output[threadIdx.x][0] += 1;
        } 
    }

    printf("finish");
    __syncthreads();
    
   return;
}

int main() {
    char *lines;
    int const NUMBER_OF_FISH = 600;

    //-----------------Read file-----------------------------------------------
    lines = (char*) malloc(NUMBER_OF_FISH); // NUMBER OF FISH
    int lenLine = readFileAsStrings("input.txt", lines);
    
    //-----------------Malloc input---------------------------------------------
    char* d_lines;
    check( cudaMalloc((char**)&d_lines, lenLine * sizeof(char)));
    check( cudaMemcpy(d_lines, lines, lenLine * sizeof(char), cudaMemcpyHostToDevice ));

    free(lines);
    //-----------------Malloc output-------------------------------------------
    // array[9][2] -> 9 = total of groups order by its current day before creating another fish
    //                2 = first -> current day / second -> num of fishes
    int h_fish[NUMBER_OF_DAYS][TWO];

    int *ptrDevice[NUMBER_OF_DAYS];
    int **_total;
    for (int i = 0; i< NUMBER_OF_DAYS; i++){

        check( cudaMalloc( (void **)&ptrDevice[i], TWO * sizeof(int)));        
    }
    check( cudaMalloc((void ***)&_total, NUMBER_OF_DAYS*TWO*sizeof(int)));
    check( cudaMemcpy(_total, ptrDevice, NUMBER_OF_DAYS*TWO*sizeof(int), cudaMemcpyHostToDevice));
    
    //-----------------Exec -----------------------
    drawMoves<<<1, NUMBER_OF_DAYS>>>(d_lines, lenLine, _total);
    cudaDeviceSynchronize();

    return 0;
}

void check(cudaError_t err){
    if (err != 0) {
        printf("error copying/malloc ");
        printf("%s",cudaGetErrorString(err));
        exit(err);           
    }
}

int readFileAsStrings(char* filename, char* lines){
    //---------------READING FILE----------------
 	FILE *fp;
	size_t len = 0;
    char *line = NULL;
    ssize_t read;
    int i = 0;
    // use dos2unix as default, win files text destroy this silently
    fp = fopen(filename, "r");
    
    if (fp == NULL)
        exit(EXIT_FAILURE);
    
        read = getline(&line, &len, fp);
       
        if (read == -1 || strlen(line) < 2){
            exit(EXIT_FAILURE);
        }

        //lines = (char*) malloc(strlen(line));        
        if (lines  == NULL) {
            printf("unable to allocate memory \n");
            return -1;
        }
        strcpy(lines, line);
        
    return strlen(line);
}