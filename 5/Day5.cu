#include <unistd.h>
#include <sys/mman.h>   /* For open(), creat()   */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define DATAXYSIZE 1001

void freeArray(int **a, int m);
int readFileAsStrings(char* filename, char* lines[1000] );
char *strRemove(char *str);
void check(cudaError_t err);

__global__ void sumMatrix(int output[][DATAXYSIZE][DATAXYSIZE], int length){

    for(int i = 1; i < length; i++){
        for(int j = 0; j < DATAXYSIZE; j++){
            for(int k = 0; k < DATAXYSIZE; k++){
                output[0][j][k] += output[i][j][k];
            }
        }
    }
    int a = 0;
    for(int j = 0; j < DATAXYSIZE; j++){
        for(int k = 0; k < DATAXYSIZE; k++){
            if (output[0][j][k] > 1){
                a++;
            }
        }
    }
    printf("%d",a);
}
__global__ void drawMoves(int ** boards, int output[][DATAXYSIZE][DATAXYSIZE], bool isEx1 ){

    int idxStart = threadIdx.x * 10;
    int idxFinish = idxStart + 10;

    int x = 0;
    int y = 0;
    int sx = 0;
    int ex = 0;
    int sy = 0;
    int ey = 0;
    
    for(int i = idxStart; i < idxFinish; i++){
        //printf("\n %d %d -> %d %d\n",boards[i][0],boards[i][1],boards[i][2],boards[i][3]);
       
        x = boards[i][2] - boards[i][0];
        y = boards[i][3] - boards[i][1];
        if (isEx1 && x!=0 && y!=0){                
                continue;
        }
        if( x==0 || y==0 ){
            
            sx = boards[i][0];
            ex = boards[i][2];
            if(sx > ex){
                sx = boards[i][2];
                ex = boards[i][0];
            }

            sy = boards[i][1];
            ey = boards[i][3];        
            if(sy>ey){
                sy = boards[i][3];
                ey = boards[i][1];
            }
            
            for(int j = sx; j<ex; j++){
                output[threadIdx.x][ey][j] = output[threadIdx.x][ey][j] + 1;
            }
            
            for(int j = sy; j<=ey; j++){
                output[threadIdx.x][j][ex] =  output[threadIdx.x][j][ex] +1;
            }
        }else{
            sx = boards[i][0];
            ex = boards[i][2];
            
            sy = boards[i][1];
            ey = boards[i][3];
            if(( x==0 || y==0 )){

                if(sx > ex){
                sx = boards[i][2];
                ex = boards[i][0];
                }
                if(sy>ey){
                    sy = boards[i][3];
                    ey = boards[i][1];
                }

                for(int j = sx; j<ex; j++){
                    output[threadIdx.x][ey][j] = output[threadIdx.x][ey][j] + 1;
                }
                
                for(int j = sy; j<=ey; j++){
                    output[threadIdx.x][j][ex] =  output[threadIdx.x][j][ex] +1;
                }
            }else {
                int moveX = 0;
                int moveY = 0;
                int incrX = (x > 0)? 1 : -1;
                int incrY = (y > 0)? 1 : -1;
                for(int j = 0; j<= incrX * x; j++){
                    output[threadIdx.x][sy+moveY][sx+moveX] += 1;
                    moveX += incrX;
                    moveY += incrY;
                }
            }    
        }
    }    
    __syncthreads();
    /*
    for(int i = 0; i<DATAXYSIZE; i++){
        printf("\n");
        for(int j = 0; j<DATAXYSIZE; j++){               
            if(output[threadIdx.x][i][j] == 0){
                printf(".");
            }else{
                printf("%d",output[threadIdx.x][i][j]);
            }               
        }
    }
    */    
   return;
}

int main() {
    
    bool const isAns1 = false;
    int NUMBER_OF_MOVES;
    
    char *lines[1000];
    NUMBER_OF_MOVES = readFileAsStrings("input.txt", lines );    
    printf("%d\n",NUMBER_OF_MOVES);
    int moves[NUMBER_OF_MOVES][4];
    //--------------------Parse Input---------------
    for(int i = 0; i< NUMBER_OF_MOVES; i++){
        strRemove(lines[i]);

        char *ptr = strtok(lines[i], ",");
        if (moves[i]  == NULL) {
            printf("unable to allocate memory \n");
            return -1;
        }
        
        moves[i][0] = atoi(ptr);
        moves[i][1] = atoi(strtok(NULL, ","));
        moves[i][2] = atoi(strtok(NULL, ","));
        moves[i][3] = atoi(strtok(NULL, ",")); 
    }
        
    //-----------------Malloc moves in device ---------
    int *ptrDevice[NUMBER_OF_MOVES];
    int **_total;
    for (int i = 0; i< NUMBER_OF_MOVES; i++){

        check( cudaMalloc( (void **)&ptrDevice[i], 4 * sizeof(int)));

        check( cudaMemcpy(ptrDevice[i], &moves[i], 4 * sizeof(int), cudaMemcpyHostToDevice));
        
    }
    check( cudaMalloc((void ***)&_total, NUMBER_OF_MOVES*4*sizeof(int)));

    check( cudaMemcpy(_total, ptrDevice, NUMBER_OF_MOVES*4*sizeof(int), cudaMemcpyHostToDevice));

    //-----------------Malloc array of matrix----------- (good luck here)
    //https://stackoverflow.com/questions/12924155/sending-3d-array-to-cuda-kernel/12925014#12925014
    
    typedef int nRarray[DATAXYSIZE][DATAXYSIZE];
    // overall data set sizes
    const int nz = NUMBER_OF_MOVES/10;
    nRarray *d_c;  // storage for result computed on device
    /*
    // allocate storage for data set
    nRarray *c; // storage for result stored on host
    c = (nRarray *)malloc((nx*ny*nz)*sizeof(int));
    if(c == 0) {
        printf("malloc1 Fail \n");
        return 1;
    }
    */
    // allocate GPU device buffers
    check( cudaMalloc((void **) &d_c, (DATAXYSIZE*DATAXYSIZE*nz)*sizeof(int)));

    //-----------------Exec reduce to NUMBER_OF_MOVES / 10-----------------------
    drawMoves<<<1, NUMBER_OF_MOVES/10>>>(_total, d_c, isAns1);
    cudaDeviceSynchronize();
    sumMatrix<<<1,1>>>(d_c,nz);
    cudaDeviceSynchronize();

    /*
    int *h_out;
    cudaMemcpy(h_out, d_out, sizeof(int *),cudaMemcpyDeviceToHost);
    printf("thiss %d",h_out);
    */
    //-----------------Exec reduce to output matrix-----------------------
    /*
    cudaMemcpy(c, d_c, ((nx*ny*nz)*sizeof(int)), cudaMemcpyDeviceToHost);
    
    cudaCheckErrors("CUDA memcpy failure");
    // and check for accuracy
    for (unsigned i=0; i<nz; i++)
      for (unsigned j=0; j<ny; j++)
        for (unsigned k=0; k<nx; k++)
          if (c[i][j][k] != (i+j+k)) {
            printf("Mismatch at x= %d, y= %d, z= %d  Host= %d, Device = %d\n", i, j, k, (i+j+k), c[i][j][k]);
            return 1;
            }
    printf("Results check!\n");
    */
    cudaFree(d_c);    
    return 0;
}

char *strRemove(char *str){
    
    int lenght = strlen(str);

    for (int i = 0; i< lenght; i++){
        if(str[i] == '-'){
            str[i]=',';
        }
        if(str[i] == '>'){
            str[i]=' ';
        }
        str[i] = str[i];
    }
    str[lenght - (1)]='\0';
    return str;
}

void check(cudaError_t err){
    if (err != 0) {
        printf("error copying ptrDevice[i] ");
        printf("%s",cudaGetErrorString(err));
        exit(err);           
    }
}

int readFileAsStrings(char* filename, char* lines[1000]){
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
    
    while (true){
        read = getline(&line, &len, fp);
       
        if (read == -1){
            break;
        }        
        if(strlen(line) < 2){
            continue;
        }
        lines[i] = (char*) malloc(strlen(line));        
        if (lines[i]  == NULL) {
            printf("unable to allocate memory \n");
            return -1;
        }
        strcpy(lines[i], line);
        i++;
        
	}
    return i;
}