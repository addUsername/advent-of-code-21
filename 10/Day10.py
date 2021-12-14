# I'm not parsing strings with variable length in cuda..

class Chunk:
    chunks = []
    open = 0
    close = 0
    char = ""

points1 = {
    ")":3,
    "}":1197,
    "]":57,
    ">":25137
}
d = {
    "(":")",
    "{":"}",
    "[":"]",
    "<":">"
}

#lines = ["{([(<{}[<>[]}>{[]{[(<()>"]


def searchClose(line, chunk):

    print(chunk.char +" "+str(chunk.open) )

    for i in range(chunk.open+1, len(line)):
        
        if(i in idxUsed):
            continue

        if line[i] is d[chunk.char]:
            return i

        elif line[i] in d.keys():
            
            c = Chunk()
            c.char = line[i]
            c.open = i            
            c.close = searchClose(line, c)            
            idxUsed.append(c.open)
            idxUsed.append(c.close)
            chunk.chunks.append(c)
        elif line[i] == "\n":
            pass
        else:
            raise Exception(line[i])


with open("input.txt","r") as f:
    lines = [a for a in f.readlines()]


idxUsed = []
total_points = 0
for line in lines:

    print("\n"+line)
    idxUsed = [0]
    c = Chunk()
    c.open = 0
    c.char = line[0]
    try:
        end = searchClose(line,c)
    except Exception as e:
        
        total_points += points1[str(e)]

print("1 - "+str(total_points))

print("2 - ")

