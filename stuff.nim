import math, nimBMP

proc random*(self: var openArray[float64], r: float64): int=
    var sum = sum(self)

    if sum == 0:
        for j in 0..self.len-1:
            self[j] = 1
        sum = sum(self)
    
    for j in 0..self.len-1:
        self[j] /= sum
    
    var x:float64 = 0

    for i in 0..self.len-1:
        x += self[i]
        if r <= x:
            return i
    
    return 0

proc get*(self: BMP, x: int, y:int): BMPRGBA=
    return self.pixels[(y * self.width)+x]

proc power*(a:int, n:int): int64=
    var product = 1.int64
    
    for i in 0..n-1:
        product *= a

    return product