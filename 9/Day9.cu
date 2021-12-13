#include <unistd.h>
#include <sys/mman.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>       // for clock_t, clock(), CLOCKS_PER_SEC

#define X 100 //100
#define Y 100 //100
#define ANS1 false


int readFileAsStrings(char* filename, char* lines[]);
void check(cudaError_t err, char *mssg);

__global__ void sum(int* d_out){

    int sum = 0;
    for(int i=0; i<Y; i++){
        sum += d_out[i];
    }
    printf("%d",sum);
}
__global__ void getDeep(int* d_in, int* d_out){

    int idx =  threadIdx.x + blockIdx.x * blockDim.x;
    int col = idx % X;
    int row = idx / X;

    // OKAY this is how you properly print and bool in c
    // printf(isDeeper ? " true " : " false ");
    bool isDeeper = true;

    //left
    if(col > 0){
        isDeeper = ( d_in[idx-1] > d_in[idx])? true: false;
        if(!isDeeper) return;
    }
    //right
    if(col < X-1){
        isDeeper = ( d_in[idx+1] > d_in[idx])? true: false;
        if(!isDeeper) return;
    }
    //up
    if(row > 0){
        isDeeper = ( d_in[idx-X] > d_in[idx])? true: false;
        if(!isDeeper) return;
    }
    //down
    if(row < Y-1){
        isDeeper = ( d_in[idx+X] > d_in[idx])? true: false;
        if(!isDeeper) return;
    }
    atomicAdd(&d_out[row],1+d_in[idx]);
}

int main() {
    //-----------------Read file-----------------------------------------------    
    char *lines[Y];
    int lenLine = readFileAsStrings("input.txt", lines);

    int *board =(int*) calloc(X*Y,sizeof(int*));
    int x = 0;
    int y = 0;
    for(int i=0; i< Y*X; i++){
        y = i / X;
        x = i % X;

        // Casting is like magic
        //char c = lines[y][x];
        //int aux = c - '0';
        //printf("%d",x);

        board[i] = lines[y][x]- '0';
    }
    //-----------------Malloc input--------------------------------------------
    int* d_in;

    check( cudaMalloc(&d_in, X*Y*sizeof(int) ),"&d_in");
    check( cudaMemcpy(d_in, board, X*Y*sizeof(int),cudaMemcpyHostToDevice),"h_in");
    //-----------------Malloc output-------------------------------------------
    int* d_out; // one int for block/row

    check( cudaMalloc((int**) &d_out, Y*sizeof(int)), "d_out");

    //---------------Find deep-------------------------------------------------
    clock_t begin = clock();

    getDeep<<<Y,X>>>(d_in, d_out);
    cudaDeviceSynchronize();

    sum<<<1,1>>>(d_out);
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

int readFileAsStrings(char* filename, char* lines[Y]){
    
 	FILE *fp;
	size_t len = 0;
    char *line = NULL;
    ssize_t read;
    
    fp = fopen(filename, "r");
    
    if (fp == NULL)
        exit(EXIT_FAILURE);
    
    int i=0;
    while( i<Y ){
        read = getline(&line, &len, fp);
        if (read == -1 ){
            printf("exit");
            exit(EXIT_FAILURE);
        }
        if ( strlen(line) < 2){
            continue;
        }
        lines[i] = (char*) malloc(X*sizeof(char)+1);
        strcpy(lines[i], line);

        //Ugly but..
        strtok(lines[i],"\n");
        i++;
    }
    
    return i;
}