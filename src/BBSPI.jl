module BBSPI

function delay end

struct CPHA0 end
struct CPHA1 end



"""
    SPISlave(; cs=chip select output pin
              clk=clock output pin
             mosi=master output pin
             miso=master input pin)

Connect to SPISlave using GPIO pins.

Methods must be defined for `setindex!(::PinType, v)` and `getindex(::PinType)`.

e.g.

```
struct Pin
    pin::UInt8
end
Base.setindex!(p::Pin, v) = gpioWrite(p.pin, v)
Base.getindex(p::Pin) = gpioRead(p.pin)
```

A SPISlave can be created with a Vector of MISO pins.
e.g. `miso=[slave1_miso, slave2_miso, slave3_miso]`.
The slaves should share common SC, CLK and MOSI pins.
In this configuration the slaves are selected simultaneously and all recieve
the same commands from the master. On every clock, each miso pin is sampled
in turn to read the individual responses of each slave.
See PiADXL.jl for an example of reading from multiple ADXL345 sensors.
"""
struct SPISlave{ClockPhase,CST,CLKT,MOSIT,MISOT}
    chip_select::CST
    clock::CLKT
    master_out::MOSIT
    master_in::MISOT

    function SPISlave{CPHA}(; cs::CST=nothing,
                             clk::CLKT=nothing,
                            mosi::MOSIT=nothing,
                            miso::MISOT=nothing,
                           ) where {CPHA,CST,CLKT,MOSIT,MISOT}

        new{CPHA,CST,CLKT,MOSIT,MISOT}(cs,clk,mosi,miso)
    end
end

SPISlave(; kwargs...) = SPISlave{CPHA1}(;kwargs...)


"""
    transfer(::SPISlave, tx_buffer, [rx_buffer])

Transfer bytes from `tx_buffer` to SPISlave.
Store response in `rx_buffer`.
"""
function transfer(s, tx, rx=UInt8[])::Nothing

    @assert isidle(s)

    rx_len = size(rx, 1)

    s.chip_select[] = 1
    delay(s)

    for i in 1:max(length(tx), rx_len)
        byte = i <= length(tx) ? tx[i] : UInt8(0)
        byte = transfer_byte(s, byte)
        if i <= rx_len
            rx[i,:] .= byte
        end
    end

    s.chip_select[] = 0
    delay(s)

    @assert isidle(s)
    nothing
end


isidle(s) = s.chip_select[] == 0 && s.clock[] == 0


function write_bit(pin, tx)
    pin[] = (tx & UInt8(0x80) == 0) ? 0 : 1
    tx << 1
end


function read_bit(pin, rx)
    rx << 1 | pin[]
end

function read_bit(pin::Vector, rx)
    rx .<< 1 .| getindex.(pin)
end


function transfer_bit(s::SPISlave{CPHA1}, tx, rx)

    s.clock[] = 1
    tx = write_bit(s.master_out, tx)
    delay(s)

    s.clock[] = 0
    rx = read_bit(s.master_in, rx)
    delay(s)

    tx, rx
end


function transfer_bit(s::SPISlave{CPHA0}, tx, rx)

    tx = write_bit(s.master_out, tx)
    delay(s)

    s.clock[] = 1
    rx = read_bit(s.master_in, rx)
    delay(s)

    s.clock[] = 0

    tx, rx
end


"""
    output_width(::SPISlave)

Number of slaves connected in parallel.
"""
output_width(pin) = 1
output_width(v::Vector) = length(v)
output_width(s::SPISlave) = output_width(s.master_in)

new_rx(pin) = UInt8(0)
new_rx(v::Vector) = zeros(UInt8, length(v))

function transfer_byte(s, tx)

    rx = new_rx(s.master_in)
    for i in 1:8
        tx, rx = transfer_bit(s, tx, rx)
    end
    rx
end



end # module
