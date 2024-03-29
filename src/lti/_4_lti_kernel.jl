# Romeo LTI kernel
#
# Implementation of kernel function for various systems.

import SpecialFunctions

"""
    kernel([T=typeof(1.0), ] sys, N, Δt)

Given a system `sys` compute its kernel vector of length `N`, uniformly
discretized with sample time `Δt`.

When simulating the response `y` of any system to a given signal `u`, the kernel is 
defined here as a sequence of samples `k` such that the response is equal to the 
discrete convolution `k ⋆ u`.
"""
kernel(sys::SisoLtiSystem, N::Integer, Δt::Real) = kernel(typeof(1.0), sys, N, Δt)

kernel(T::Type{<:Number}, sys::ZeroSys, N::Integer, Δt::Real) = zeros(T, N)
kernel(T::Type{<:Number}, sys::UnitSys, N::Integer, Δt::Real) = convid(T, N)


function kernel(T::Type{<:Number}, sys::Diff{<:Number}, N::Integer, Δt::Real)
    @assert N ≥ 1 "Kernel should be at least one sample long"
    if sys.α == 0
        res = zeros(T, N)
        res[1] = one(T)
        return res
    elseif sys.α == 1
        res = zeros(T, N)
        res[1] = one(T)
        res[2] = -one(T)
        return res / Δt
    elseif real(sys.α) > 0
        # TODO: fix this branch
        ddt = kernel(T, Diff(one(typeof(sys.α))), N, Δt)
        temp = kernel(T, Diff(sys.α - 1), N, Δt)
        return convolve(ddt, temp)
    elseif real(sys.α) < 0
        ikt = (0:N) .^ (-sys.α)
        return (ikt[2:end] - ikt[1:end-1]) .* (Δt^(-sys.α) / SpecialFunctions.gamma(-sys.α + 1))
    else
        @error "Not implemented!"
    end
end

kernel(T::Type{<:Number}, sys::ScaledSystem, N::Integer, Δt::Real) = sys.k * kernel(T, sys.inner, N, Δt)
kernel(T::Type{<:Number}, sys::ParallelSystem, N::Integer, Δt::Real) = kernel(T, sys.first, N, Δt) .+ kernel(T, sys.second, N, Δt)
kernel(T::Type{<:Number}, sys::SeriesSystem, N::Integer, Δt::Real) = convolve(kernel(T, sys.first, N, Δt), kernel(T, sys.second, N, Δt))
kernel(T::Type{<:Number}, sys::RationalSystem, N::Integer, Δt::Real) = deconvolve(kernel(T, sys.num, N, Δt), kernel(T, sys.den, N, Δt))

function kernel(T::Type{<:Number}, sys::PowerSystem{<:Number}, N::Integer, Δt::Real)
    if imag(sys.α ≠ 0)
        @error "Cannot compute kernel of a complex power of an arbitrary system."
    end
    α = real(sys.α)
    if α > 0
        if floor(α) == α
            k1 = kernel(T, sys.inner, N, Δt)
            k = copy(k)
            for i = 2:floor(Int, sys.α)
                k = convolve(k, k1)
            end
            return k
        else
            h = floor(Int, α)
            r = α - h
            if r == 0.5
                k1 = convroot(kernel(T, sys.inner, N, Δt))
                k = copy(k)
                for i = 2 * floor(Int, h) + 1
                    k = convolve(k, k1)
                end
                return k
            else
                @error "Unable to compute kernel of this power system."
            end
        end
    else
        convinv(kernel(T, PowerSystem(-sys.α, sys.inner), N, Δt))
    end
end

export kernel