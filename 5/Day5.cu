#include <unistd.h>
#include <sys/mman.h>   /* For open(), creat()   */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int readFileAsStrings(char* filename, char* lines[1000] );
char *strRemove(char *str);
void check(cudaError_t err);

// this process just one board, so there is a gpu thread per board
__global__ void drawMoves(int ** boards, int SIZE, bool isEx1 ){
    
    
    __shared__ int shared;
    
    //printf("%d",boards[0][1]);
    int idxStart = threadIdx.x * 10;
    int idxFinish = idxStart + 10;
    int d_matrix[10][10];

    
    // ini temp matrix
    for(int i = 0; i<SIZE; i++){
      //  d_matrix[i] = (int*) malloc(SIZE * sizeof(int)); //??
        for(int j = 0; j<SIZE; j++){
            d_matrix[i][j] = 0;
        }
    }
    
    int x = 0;
    int y = 0;
    int sx = 0;
    int ex = 0;
    int sy = 0;
    int ey = 0;
                //0         //10
    for(int i = idxStart; i<idxFinish; i++){
     //   x = boards[i][2] - boards[i][0];
     //   y = boards[i][3] - boards[i][1];
        printf("\n %d %d -> %d %d",boards[i][0],boards[i][1],boards[i][2],boards[i][3]);
        if(isEx1){
            x = boards[i][2] - boards[i][0];
            y = boards[i][3] - boards[i][1];
            if(x!=0 && y!=0){
                printf("skipping");
                continue;
            }
        }
        //Draw horizontal
        sx = boards[i][0]; //8
        ex = boards[i][2]; //0

        if(sx > ex){
            sx = boards[i][2];//0 
            ex = boards[i][0];//8
        }

        for(int j = sx; j<=ex; j++){
            d_matrix[boards[i][3]][j] = d_matrix[boards[i][3]][j] + 1;
        }

        //Draw vertical
        sy = boards[i][1];
        ey = boards[i][3];
        printf("vertical\n");

        if(sy>ey){
            sy = boards[i][3];
            ey = boards[i][1];
        }
        
        for(int j = sy; j<ey; j++){
            d_matrix[j][ex] = d_matrix[j][ex] + 1;
        }

        for(int i = 0; i<SIZE; i++){
            printf("\n");
            for(int j = 0; j<SIZE; j++){
                    printf("%d",d_matrix[i][j]);
            }
        }
        
        printf("\n");

    }

}

int main() {

    
    bool const isAns1 = true;

    int const SIZE = 10;
    int NUMBER_OF_MOVES;
    
    char *lines[1000];
    NUMBER_OF_MOVES = readFileAsStrings("inputa.txt", lines );    
    printf("%s",lines[0]);

    int moves[NUMBER_OF_MOVES][4];
    //--------------------Parse Input---------------
    for(int i = 0; i< NUMBER_OF_MOVES-1; i++){
        strRemove(lines[i]);

        char *ptr = strtok(lines[i], ",");

    
       // moves[i] = (int*) malloc(4*sizeof(int));
        if (moves[i]  == NULL) {
            printf("unable to allocate memory \n");
            return -1;
        }
        
        moves[i][0] = atoi(ptr);
        moves[i][1] = atoi(strtok(NULL, ","));
        moves[i][2] = atoi(strtok(NULL, ","));
        moves[i][3] = atoi(strtok(NULL, ",")); 
    }
    printf("%d %d %d %d\n", moves[0][0], moves[0][1], moves[0][2], moves[0][3]);
    

    //-----------------Malloc moves in device ---------
    int *ptrDevice[NUMBER_OF_MOVES];
    int **_total;
    for (int i = 0; i< NUMBER_OF_MOVES-1; i++){

        check( cudaMalloc( (void **)&ptrDevice[i], 4 * sizeof(int)));

        check( cudaMemcpy(ptrDevice[i], &moves[i], 4 * sizeof(int), cudaMemcpyHostToDevice));
    }

    check( cudaMalloc((void ***)&_total, NUMBER_OF_MOVES*4*sizeof(int)));

    check( cudaMemcpy(_total, ptrDevice, NUMBER_OF_MOVES*4*sizeof(int), cudaMemcpyHostToDevice));

    drawMoves<<<1, NUMBER_OF_MOVES/10>>>(_total,SIZE, isAns1);
    cudaDeviceSynchronize();

    //-----------------Malloc array of matrix----------- (good luck here)

    //-----------------Exec reduce to NUMBER_OF_MOVES / 10-----------------------

    //-----------------Exec reduce to output matrix-----------------------
    
    
    return 0;




}
char *strRemove(char *str){
    
    int lenght = strlen(str);
   // printf("\n %d \n",lenght);

    for (int i = 0; i< lenght; i++){
        //printf(" %c ",str[i+end]);
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