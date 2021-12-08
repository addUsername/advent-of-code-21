#include <unistd.h>
#include <sys/mman.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define NUMBER_OF_DAYS 256
#define NUMBER_OF_GROUPS 9
#define TWO 2

int readFileAsStrings(char* filename, char* lines);
void check(cudaError_t err, char *mssg);

__global__ void addDays(long** output){

    int nextDayChild = 0;

    for (int i = 0; i<NUMBER_OF_DAYS; i++){
        for (int day = 0; day<9; day++){
            if ( output[day][0] == 0){
                output[day][0] = 8;
                nextDayChild =(day + 7 > 8 )? day - 2 : day + 7 ;
                output[nextDayChild][1] += output[day][1];
            }else{
                output[day][0] -= 1;
            }
        }
    }
    long sum = 0;
    for(int i = 0; i<9; i++){
        sum += output[i][1];
    }
    printf("\nout: %ld ",sum);
}
__global__ void drawMoves(char * input, int length, long **output){

    int day = threadIdx.x;
    int ascciValue = 48 + threadIdx.x;

    for (int i = 0; i <length; i++){
        if ((int) input[i] == ascciValue){
            output[threadIdx.x][1] += 1;
        } 
    }
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
    check( cudaMalloc((char**)&d_lines, lenLine * sizeof(char)), "&d_lines");
    check( cudaMemcpy(d_lines, lines, lenLine * sizeof(char), cudaMemcpyHostToDevice ), "d_lines");

    free(lines);
    //-----------------Malloc output-------------------------------------------
    // array[9][2] -> 9 = total of groups order by its current day before creating another fish
    //                2 = first -> current day / second -> num of fishes
    typedef long nRarray[NUMBER_OF_GROUPS][TWO];
    nRarray *d_total;

    long *ptrDevice[NUMBER_OF_GROUPS];
    long **_total;
    for (int i = 0; i< NUMBER_OF_GROUPS; i++){
        long b[2] = {i,0};
        check( cudaMalloc( (void **)&ptrDevice[i], TWO * sizeof(long)), "&ptrDevice");
        check( cudaMemcpy(ptrDevice[i], b, TWO*sizeof(long), cudaMemcpyHostToDevice), "ptrDevice" );       
    }
    check( cudaMalloc((void ***)&_total, NUMBER_OF_GROUPS*TWO*sizeof(long)), "&_total");
    check( cudaMemcpy(_total, ptrDevice, NUMBER_OF_GROUPS*TWO*sizeof(long), cudaMemcpyHostToDevice), "ptrDevice" );
    
    //-----------------Exec -----------------------
    drawMoves<<<1, NUMBER_OF_GROUPS>>>(d_lines, lenLine, _total);
    cudaDeviceSynchronize();
    cudaFree(d_lines);

    addDays<<<1,1>>>(_total);
    cudaDeviceSynchronize();
    cudaFree(_total);

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
        strcpy(lines, line);
        
    return strlen(line);
}