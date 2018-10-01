import random, math, stuff, nimBMP

const DX* = [-1, 0, 1, 0]
const DY* = [0, 1, 0, -1]
var opposite* {.global.} = [2, 3, 0, 1]

type 
    Observation = enum
        succ, fail, cont
    Model* = ref object of RootObj
        wave: seq[seq[bool]]

        propagator: seq[seq[seq[int]]]
        compatible*: seq[seq[seq[int]]]
        observed: seq[int]

        stack*: seq[tuple[index: int, value: int]]
        stacksize*: int

        random: Rand
        FMX*, FMY*, T: int
        periodic*: bool

        weights: seq[float64]
        weightLogWeights*: seq[float64]

        sumsOfOnes*: seq[int]
        sumOfWeights*, sumOfWeightLogWeights*, startingEntropy*: float64
        sumsOfWeights*, sumsOfWeightLogWeights*, entropies*: seq[float64]

        onBoundary: proc(x: int, y: int): bool {.closure.}
        graphics: proc(): BMP {.closure.}

proc init*(self: Model) =
    self.wave.setLen(self.FMX * self.FMY)
    self.compatible.setLen(self.wave.len)

    for i in 0..self.wave.len-1:
        self.wave[i].setLen(self.T)
        self.compatible[i].setLen(self.T)
        for t in 0..self.T-1:
            self.compatible[i][t].setLen(4)
    
    self.weightLogWeights.setLen(self.T)
    self.sumOfWeights = 0
    self.sumOfWeightLogWeights = 0

    for t in 0..self.T-1:
        self.weightLogWeights[t] = self.weights[t] * self.weights[t].ln
        self.sumOfWeights += self.weights[t]
        self.sumOfWeightLogWeights += self.weightLogWeights[t]
    
    self.startingEntropy = self.sumOfWeights.ln - self.sumOfWeightLogWeights / self.sumOfWeights

    self.sumsOfOnes.setLen(self.FMX * self.FMY)
    self.sumsOfWeights.setLen(self.FMX * self.FMY)
    self.sumsOfWeightLogWeights.setLen(self.FMX * self.FMY)
    self.entropies.setLen(self.FMX * self.FMY)

    self.stack.setLen(self.wave.len * self.T)
    self.stacksize = 0


proc ban(self: Model, i:int, t:int) =
    self.wave[i][t] = false

    var comp = self.compatible[i][t]
    for d in 0..3:
        comp[d] = 0
    
    self.stack[self.stacksize] = (index: i, value: t)
    self.stacksize += 1

    var sum = self.sumsOfWeights[i]
    self.entropies[i] += self.sumsOfWeightLogWeights[i] / sum - sum.ln

    self.sumsOfOnes[i] -= 1
    self.sumsOfWeights[i] -= self.weights[t]
    self.sumsOfWeightLogWeights[i] -= self.weightLogWeights[t]

    sum = self.sumsOfWeights[i]
    self.entropies[i] -= self.sumsOfWeightLogWeights[i] / sum - sum.ln


proc observe*(self: Model): Observation=
    var min:float64 = 1E+3
    var argmin = -1

    for i in 0..self.wave.len-1:
        # TODO: mod & div over / & % ?
        if self.onBoundary(i mod self.FMX, i div self.FMX):
            continue
        
        let ammount = self.sumsOfOnes[i]
        if ammount == 0:
            return Observation.fail
        
        let entropy = self.entropies[i]
        if ammount > 1 and entropy <= min:
            let noise = 1E-6 * self.random.next().float64
            if entropy + noise < min:
                min = entropy + noise
                argmin = i
    
    if argmin == -1:
        self.observed.setLen(self.FMX * self.FMY)
        for i in 0..self.wave.len-1:
            for t in 0..self.T-1:
                if self.wave[i][t]:
                    self.observed[i] = t
                    break
        return Observation.succ
    
    var distribution = newSeq[float64](self.T)
    for t in 0..self.T-1:
        distribution[t] = if self.wave[argmin][t]: self.weights[t]
                                             else: 0
    let r = distribution.random(self.random.next().float64)                 
    
    let w = self.wave[argmin] 
    for t in 0..self.T-1:
        if w[t] != (t == r):
            self.ban(argmin, t)
    
    return Observation.cont


proc propogate(self: Model) = 
    while self.stacksize > 0:
        let e1 = self.stack[self.stacksize-1]
        self.stacksize -= 1

        let i1 = e1.index
        let x1 = i1 mod self.FMX
        let y1 = i1 div self.FMX
        let w1 = self.wave[i1]

        for d in 0..3:
            let dx = DX[d]
            let dy = DY[d]
            var x2 = x1 + dx
            var y2 = y1 + dx
            if self.onBoundary(x2, y2):
                continue

            if x2 < 0:
                x2 += self.FMX
            elif x2 >= self.FMX:
                x2 -= self.FMX
            
            if y2 < 0:
                y2 += self.FMY
            elif y2 >= self.FMY:
                y2 -= self.FMY

            let i2 = x2 + y2 * self.FMX
            let p = self.propagator[d][e1.value]
            let compat = self.compatible[i2]

            for l in 0..p.len-1:
                let t2 = p[l]
                var comp = compat[t2]

                comp[d] -= 1
                if comp[d] == 0:
                    self.ban(i2, t2)

proc clear(self: Model)=
    for i in 0..self.wave.len-1:
        for t in 0..self.T-1:
            self.wave[i][t] = true
            for d in 0..3:
                self.compatible[i][t][d] = self.propagator[opposite[d]][t].len
        
        self.sumsOfOnes[i] = self.weights.len
        self.sumsOfWeights[i] = self.sumOfWeights
        self.sumsOfWeightLogWeights[i] = self.sumOfWeightLogWeights
        self.entropies[i] = self.startingEntropy


proc run*(self: Model, seed: int, limit: int): bool=
    if self.wave.len == 0:
        self.init
    
    self.clear
    self.random = initRand(seed)

    var i = 0
    
    # TODO: Correct funcitonality?
    while i < limit or limit == 0:
        let result = self.observe()
        if result == Observation.succ:
            return true
        elif result == Observation.fail:
            return false
        self.propogate
    
    return true

