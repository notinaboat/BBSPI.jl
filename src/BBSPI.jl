"""
# BBSPI

Julia implementation of Bit Banged
[SPI](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface)

See https://github.com/notinaboat/PiADXL345.jl for usage example.


## TODO

 * Try putting the `delay` function in `struct SPISlave`.
   Does the delay loop still get inlined nicely?

"""
module BBSPI

function delay end

struct CPHA0 end
struct CPHA1 end



"""
    SPISlave(; cs=chip_select_output_pin,
              clk=clock_output_pin,
             mosi=master_output_pin,
             miso=master_input_pin)

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

    rx_len = length(rx)
    tx_len = length(tx)

    s.chip_select[] = 1
    delay(s)

    for i in 1:max(tx_len, rx_len)
        byte = i <= tx_len ? tx[i] : UInt8(0)
        byte = transfer_byte(s, byte)
        if i <= rx_len
            rx[i] = byte
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


function transfer_byte(s, tx)

    rx = UInt8(0)
    for i in 1:8
        tx, rx = transfer_bit(s, tx, rx)
    end
    rx
end



end # module
