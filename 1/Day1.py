# https://adventofcode.com/2021/day/1

with open("input.txt","r") as f:
    x = [int(a) for a in f.readlines()]

#1
steps = [(1 if x[i] > x[i-1] else 0) for i in range (1, len(x))]
print(sum(steps))

#2
# Okay, its seems that you can't get Index Out Of Bounds Exception while slicing in python, feels wrong but ok
steps2 = [(1 if sum(x[i+1:i+4]) > sum(x[i:i+3]) else 0) for i in range (len(x))]
print(sum(steps2))

