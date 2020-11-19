using Test
using BBSPI

@testset "BBSPI" begin

    # Input pin that produces a test pattern
    mutable struct TestOutPin
        bit
        bits
    end
    Base.getindex(b::TestOutPin) = b.bit
    Base.length(b::TestOutPin) = 1


    # Output pins that reocrd the output value
    mutable struct TestInPin
        v
    end
    Base.getindex(c::TestInPin) = c.v


    function Base.setindex!(pin::TestInPin, v)

        if pin == clk
            # On rising clock edge, load a bit into MISO...
            if pin.v == 0 && v == 1
                if miso isa Vector
                    for p in miso
                        p.bit = popfirst!(p.bits)
                    end
                else
                    miso.bit = popfirst!(miso.bits)
                end
            end
#            println(  "clock = ", v,
#                    ", cs = ", cs.v,
#                    ", mosi = ", mosi.v,
#                    ", miso = ",  miso.bit)
        end

        # Record transmitted bits
        if pin == mosi
            push!(txbuf, v)
        end
    end

    rxbuf = zeros(UInt8, 4)

    BBSPI.delay(s::BBSPI.SPISlave) = nothing


    cs = TestInPin(0)
    clk = TestInPin(0)
    mosi = TestInPin(0)
    txbuf = Int[]
    miso = TestOutPin(-1, [0,1,0,1,0,1,0,1,
                           1,0,1,0,1,0,1,0,
                           0,1,0,1,0,1,0,1,
                           1,0,1,0,1,0,1,0])

    spi = BBSPI.SPISlave(cs=cs, clk=clk, mosi=mosi, miso=miso)

    BBSPI.transfer(spi, [0xAA, 0x55], rxbuf)
    @test rxbuf == [0x55, 0xaa, 0x55, 0xaa]
    @test txbuf == [1,0,1,0,1,0,1,0,
                    0,1,0,1,0,1,0,1,
                    0,0,0,0,0,0,0,0,
                    0,0,0,0,0,0,0,0]

    cs = TestInPin(0)
    clk = TestInPin(0)
    mosi = TestInPin(0)
    txbuf = Int[]
    miso1 = TestOutPin(-1, [0,1,0,1,0,1,0,1,
                            1,0,1,0,1,0,1,0,
                            0,1,0,1,0,1,0,1,
                            1,0,1,0,1,0,1,0])

    miso2 = TestOutPin(-1, [1,0,1,0,1,0,1,0,
                            0,1,0,1,0,1,0,1,
                            1,0,1,0,1,0,1,0,
                            0,1,0,1,0,1,0,1])

    miso = [miso1, miso2]

    spi = BBSPI.SPISlave(cs=cs, clk=clk, mosi=mosi, miso=miso)

    rxbuf = zeros(UInt8, 4, 2)

    BBSPI.transfer(spi, [0xAA, 0x55], rxbuf)

    @test rxbuf[:,1] == [0x55, 0xaa, 0x55, 0xaa]
    @test rxbuf[:,2] == [0xaa, 0x55, 0xaa, 0x55]
end
