import model, colors, nimBMP, strformat, stuff
type
    OverlappingModel = ref object of Model
        N: int
        patterns: seq[seq[byte]]
        colors: seq[BMPRGBA]
        ground: int

proc newOverlappingModel(name: string, N: int, width: int, height: int, periodicInput: bool, periodicOutput: bool, symmetry: int, ground: int): OverlappingModel=
    result = OverlappingModel(FMX: width, FMY: height, periodic: periodicOutput)
    result.N = N
    
    var bmp = loadBMP(fmt"samples/{name}.png")
    let SMX = bmp.width
    let SMY = bmp.height

    # Budget matrix
    var sample = newSeq[seq[byte]](SMX)
    for i in 0..SMX:
        sample[i].setLen(SMY)
    
    for x in 0..SMX-1:
        for y in 0..SMY-1:
            let color = bmp.get(x, y)
            
            var i = 0
            for c in items(result.colors):
                if c == color: 
                    break
                i += 1
            
            if i == result.colors.len:
                result.colors.add(color)

            sample[x][y] = i.byte
    
    let C = result.colors.len
    let W = power(C, N * N)
