import math

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