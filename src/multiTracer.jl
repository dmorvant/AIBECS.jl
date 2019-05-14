
#=============================================
Generate 𝐹 and ∇ₓ𝐹 from user input
=============================================#

# Create F and ∇ₓF automatically from Ts and Gs only
function state_function_and_Jacobian(Ts, Gs, nb)
    nt = length(Ts)
    tracers(v) = [v[j:j+nb-1] for j in 1:nb:nb*nt]
    T(p) = blockdiag([Tⱼ(p) for Tⱼ in Ts]...) # Big T (linear part)
    G(x, p) = reduce(vcat, [Gⱼ(tracers(x)..., p) for Gⱼ in Gs]) # nonlinear part
    F(x, p) = -T(p) * x + G(x, p)                     # full 𝐹(𝑥) = T 𝑥 + 𝐺(𝑥)
    ∇ₓG(x, p) = local_jacobian(Gs, x, p, nt, nb)     # Jacobian of nonlinear part
    ∇ₓF(x, p) = -T(p) + ∇ₓG(x, p)          # full Jacobian ∇ₓ𝐹(𝑥) = T + ∇ₓ𝐺(𝑥)
    return F, ∇ₓF
end
export state_function_and_Jacobian

function local_jacobian(Gs, x, p, nt, nb)
    return reduce(vcat, [local_jacobian_row(Gⱼ, x, p, nt, nb) for Gⱼ in Gs])
end

𝔇(x) = DualNumbers.dualpart.(x)      # dual part

function local_jacobian_row(Gⱼ, x, p, nt, nb)
    e(j) = kron([j == k for k in 1:nt], trues(nb))
    tracers(v) = [v[j:j+nb-1] for j in 1:nb:nb*nt]
    return reduce(hcat, [sparse(Diagonal(𝔇(Gⱼ(tracers(x + ε * e(j))..., p)))) for j in 1:nt])
end

#=============================================
Generate 𝑓 and derivatives from user input
=============================================#

function generate_objective(ωs, μx, σ²x, v, ωp, μp, σ²p)
    nt, nb = length(ωs), length(v)
    tracers(x) = [x[j:j+nb-1] for j in 1:nb:nb*nt]
    f(x, p) = ωp * mismatch(p, μp, σ²p) +
        sum([ωⱼ * mismatch(xⱼ, μⱼ, σⱼ², v) for (ωⱼ, xⱼ, μⱼ, σⱼ²) in zip(ωs, tracers(x), μx, σ²x)])
    return f
end

function generate_∇ₓobjective(ωs, μx, σ²x, v, ωp, μp, σ²p)
    nt, nb = length(ωs), length(v)
    tracers(x) = [x[j:j+nb-1] for j in 1:nb:nb*nt]
    ∇ₓf(x, p) = reduce(hcat, [ωⱼ * ∇mismatch(xⱼ, μⱼ, σⱼ², v) for (ωⱼ, xⱼ, μⱼ, σⱼ²) in zip(ωs, tracers(x), μx, σ²x)])
    return ∇ₓf
end

function generate_∇ₚobjective(ωs, μx, σ²x, v, ωp, μp, σ²p)
    nt, nb = length(ωs), length(v)
    tracers(x) = [x[j:j+nb-1] for j in 1:nb:nb*nt]
    ∇ₚf(x, p) = ωp * ∇mismatch(p, μp, σ²p)
    return ∇ₚf
end
export generate_objective, generate_∇ₓobjective, generate_∇ₚobjective

"""
    mismatch(x, xobs, σ²xobs, v)

Volume-weighted mismatch of modelled tracer `x` against observed mean, `xobs`, given observed variance, `σ²xobs`, and volumes `v`.
"""
function mismatch(x, xobs, σ²xobs, v)
    δx = x - xobs
    W = Diagonal(v ./ σ²xobs)
    return 0.5 * transpose(δx) * W * δx / (transpose(xobs) * W * xobs)
end

mismatch(x, ::Missing, args...) = 0

"""
    ∇mismatch(x, xobs, σ²xobs, v)

Adjoint of the gradient of `mismatch(x, xobs, σ²xobs, v)`.
"""
function ∇mismatch(x, xobs, σ²xobs, v)
    δx = x - xobs
    W = Diagonal(v ./ σ²xobs)
    return transpose(W * δx) / (transpose(xobs) * W * xobs)
end
∇mismatch(x, ::Missing, args...) = transpose(zeros(length(x)))

# TODO
# Talk about it with FP
# Assumptions: 
# 1. The prior distributions of the parameters, p, are log-normal
# 2. The values `mean_obs` and `variance_obs` are the non-log mean and variance,
# Then the mean and variance of the prior of log(p) are
# logμ = log(μ / √(1 + σ² / μ²))
# logσ² = log(1 + σ² / μ²)
# These are the values we use for the mismatch
"""
    mismatch(p, m, v)

Returns the mismatch of the model parameters `p` against observations.
Assumes priors have a log-normal distributions.
`m` and `v` are the non-log mean and variances,
and are converted to their log counterparts in the mismatch formula.
"""
function mismatch(p, m, v)
    μ = log.(m ./ sqrt.(1 .+ m ./ v.^2))
    σ² = log.(1 .+ v ./ m.^2)
    δλ = log.(optvec(p)) .- μ
    W = Diagonal(1 ./ σ²)
    return 0.5 * transpose(δλ) * W * δλ
end
function ∇mismatch(p, m, v)
    μ = log.(m ./ sqrt.(1 .+ m ./ v.^2))
    σ² = log.(1 .+ v ./ m.^2)
    δλ = log.(optvec(p)) .- μ
    W = Diagonal(1 ./ σ²)
    return transpose(W * δλ ./ optvec(p))
end


#=============================================
Generate multi-tracer norm
=============================================#

function volumeweighted_norm(nt, v)
    w = repeat(v, nt)
    return nrm(x) = transpose(x) * Diagonal(w) * x
end



