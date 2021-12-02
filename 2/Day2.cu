#include <fcntl.h>    /* For O_RDWR */
#include <unistd.h>
#include <sys/mman.h>   /* For open(), creat()   */
#define _GNU_SOURCE

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

struct Position{
	int h;
	int v;
	int aim;
};

/*

__global__ void cuda_hello(struct Position *p){

	printf("hello\n");
    //printf("%d aaaa %d\n",*p.h, *p.v);
	//p->h = 100;
}
*/

int main() {
	
	// nvcc -o a a.cu	

 	FILE * fp;
    char * line = NULL;
    size_t len = 0;
    ssize_t read;

	struct Position p;
	struct Position p2;
	p.h = 0;
	p.v = 0;

	p2.h = 0;
	p2.v = 0;
	p2.aim = 0;
	
    fp = fopen("input.txt", "r");
    if (fp == NULL)
        exit(EXIT_FAILURE);

	char dest[1];
    while ((read = getline(&line, &len, fp)) != -1) {
        //printf("Retrieved line of length %zu:\n", read);
        
		// forward down up 
		switch (line[0])
		{
		case 'f':			
			memcpy(dest, line + 7, sizeof(int));	
			p.h = p.h + atoi(dest);
			p2.h = p2.h + atoi(dest);
			p2.v = p2.v + (p2.aim * atoi(dest));
			break;
		case 'u':
			memcpy(dest, line + 2, sizeof(int));
			p.v = p.v - atoi(dest);
			p2.aim = p2.aim - atoi(dest);
			break;
		case 'd':
			memcpy(dest, line + 4, sizeof(int));
			p.v = p.v + atoi(dest);
			p2.aim = p2.aim + atoi(dest);
			break;		
		default:
			break;
		}
    }

    fclose(fp);
    if (line)
        free(line);
	printf("%d",p.h * p.v);
	printf("\n%d",p2.h * p2.v);
    exit(EXIT_SUCCESS);
}