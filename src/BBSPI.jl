module BBSPI

function delay end

struct CPHA0 end
struct CPHA1 end


struct SPISlave{ClockPhase,PinOut,PinIn}
    chip_select::PinOut
    clock::PinOut
    master_out::PinOut
    master_in::PinIn
end


SPISlave(; kwargs...) = SPISlave{CPHA1}(;kwargs...)

function SPISlave{CPHA}(; cs::PinOut=nothing,
                         clk::PinOut=nothing,
                        mosi::PinOut=nothing,
                        miso::PinIn=nothing,
                       ) where {CPHA,PinOut,PinIn}
    
    SPISlave{CPHA,PinOut,PinIn}(cs, clk, mosi, miso)
end


isidle(s) = s.chip_select[] == 0 && s.clock[] == 0


function write_bit(s, tx)::UInt8
    s.master_out[] = (tx & UInt8(0x80) == 0) ? 0 : 1
    delay(s)
    tx << 1
end


function read_bit(s, rx)::UInt8
    rx = rx << 1 | s.master_in[]
    delay(s)
    rx
end


function transfer_bit(s::SPISlave{CPHA1}, tx, rx)

    s.clock[] = 1
    tx = write_bit(s, tx)

    s.clock[] = 0
    rx = read_bit(s, rx)

    tx, rx
end


function transfer_bit(s::SPISlave{CPHA0}, tx, rx)

    tx = write_bit(s, tx)

    s.clock[] = 1
    rx = read_bit(s, rx)

    s.clock[] = 0

    tx, rx
end


function transfer_byte(s, tx)::UInt8

    rx = UInt8(0)
    for i in 1:8
        tx, rx = transfer_bit(s, tx, rx)
    end
    rx
end


function transfer(s, output, input)::Nothing

    @assert isidle(s)

    s.chip_select[] = 1
    delay(s)

    for i in 1:length(input)
        byte = i <= length(output) ? output[i] : UInt8(0)
        input[i] = transfer_byte(s, byte)
    end

    s.chip_select[] = 0
    delay(s)

    @assert isidle(s)
    nothing
end



end # module
