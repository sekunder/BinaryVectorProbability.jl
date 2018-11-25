
"""
    likelihood(X, P, normalized=true)

Computes the likelihood of `X` given distribution `P`
"""
function likelihood(X, P::AbstractBinaryVectorDistribution, normalized=true)
    Px = [pdf(P, X[:,k]) for k = 1:size(X,2)]
    if normalized
        Px = Px .^ (1 / size(X,2))
    end
    return prod(Px)
end


"""
    loglikelihood(X, P, normalized=true)

Computes the log likelihood of `X` given distribution `P`. Returns `0.0` if `P`
assigns probability 0 to any column of `X`
"""
function loglikelihood(X, P::AbstractBinaryVectorDistribution, normalized=true)
    Px = [pdf(P, X[:,k]) for k = 1:size(X,2)]
    if any(Px .== 0.0)
        return 0.0
    end
    return sum_kbn(map(log,Px)) / (normalized ? size(X,2) : 1)
end

"""
    loglikelihood(X, Jtilde, grad)

Computes the loglikelihood of the data given the Ising distribution generated by
`Jtilde`. If `grad` is a vector of length > 0, it is modified in-place with the
gradient of the function.

"""
function loglikelihood(X, Jtilde::Vector, grad::Vector=[]; mu_X=(X*X'/size(X,2)), kwargs...)
    (N_neurons, N_samples) = size(X)

    Jtilde = reshape(Jtilde, N_neurons,N_neurons)
    P = IsingDistribution(Jtilde)

    if length(grad) > 0
        # performing this computation first, if it's necessary, results in all
        # the pdf values being cached.
        # mu_X = X * X' / N_samples
        mu_P = expectation_matrix(P)
        grad[:] = -(mu_P - mu_X)[:]
        grad[1:(N_neurons+1):end] = diag(mu_P - mu_X)[:]

    end
    # return sum_kbn([log(pdf(P, X[:,k])) for k = 1:N_samples]) / N_samples
    return -log(_get_Z(P)) - (sum_kbn([_E_Ising(P, X[:,i]) for i = 1:N_samples])) / N_samples
end

"""
    MPF_objective(X, J, grad)

Uses function `K` from the MPF paper (or maybe from the MPF sample code for
Matlab). Using this to fit J will typically result in values close to optimal,
but the advantage is that this method does not involve computing the partition
function Z.

"""
function MPF_objective(X, Jtilde::Vector, grad::Vector=[])
    (N_neurons, N_samples) = size(X)
    Jtilde = reshape(Jtilde, N_neurons, N_neurons)
    theta = diag(Jtilde)
    J = Jtilde - Diagonal(Jtilde)
    DeltaX = 2 * X - 1 # this is Δx_l for each codeword x, for each index l
    # Kfull = exp.((-0.5 * DeltaX .* (J * X) + DeltaX .* theta)/2)
    Kfull = exp.((DeltaX .* theta - DeltaX .* (J * X)) / 2)
    K = sum_kbn(Kfull[:]) / N_samples
    if length(grad) > 0
        # M = zeros(N_neurons, N_neurons)
        # M[1:(N_neurons+1):end] = sum(0.5 * Kfull .* DeltaX, 2) / N_samples
        # for p = 1:(N_neurons - 1)
        #     for q = (p+1):N_neurons
        #         M[p,q] = M[q,p] = -0.5 * sum([(Kfull[p,w] * DeltaX[p,w] * X[q,w] + Kfull[q,w] * DeltaX[q,w] * X[p,w]) for w = 1:N_samples]) / N_samples
        #     end
        # end
        DK = Kfull .* DeltaX
        dJ = -0.5 * DK * X'
        dJ = (dJ + dJ') / 2
        dJ[1:(n+1):end] = 0.5 * sum(DK, 2)
        grad[:] = dJ[:] / N_samples
    end
    return K
end

"""
    K_MPF(X, Jtilde)

Computes the function ``K_X`` for data `X` and parameters `Jtilde`. This version is meant
for use with the `Optim` package, which in particular uses a separate function for the
optimization function and gradient function. See also `dK_MPF!`

"""
function K_MPF(X, Jtilde)
    N_neurons, N_samples = size(X)
    J = reshape(Jtilde, N_neurons, N_neurons)
    theta = diag(J)
    J[1:(N_neurons+1):end] = 0.0
    ΔX = 2X - 1 # flip bits in X
    Kfull = exp.(0.5 * (ΔX .* theta - ΔX .* (J * X)))
    return sum_kbn(Kfull) / N_samples
end

"""
    dK_MPF!(X, G, Jtilde)

Computes the gradient of `K_MPF` and modifies `G` in-place.
"""
function dK_MPF!(X, G, Jtilde)
    N_neurons, N_samples = size(X)
    J = reshape(Jtilde, N_neurons, N_neurons)
    theta = diag(J)
    J[1:(N_neurons+1):end] = 0.0
    ΔX = 2X - 1 # flip bits in X
    Kfull = exp.(0.5 * (ΔX .* theta - ΔX .* (J * X)))
    # M = zeros(N_neurons, N_neurons)
    # M[1:(N_neurons+1):N_neurons] = sum(0.5 * ΔX .* Kfull, 2)
    DK = Kfull .* ΔX
    dJ = -0.5 * (Kfull .* ΔX) * X'
    dJ = (dJ + dJ') / 2
    dJ[1:(N_neurons+1):end] = 0.5 * sum(DK, 2)
    G[:] = dJ[:] / N_samples
end
function Kf_and_DX!(Jtilde, last_J, Kf_X_DX)
    if J != last_J
        last_J[:] = J[:] # Copy the last value of J over
        #TODO sort this out if necessary.

        N_neurons, N_samples = size(X)
        J = reshape(Jtilde, N_neurons, N_neurons)
        theta = diag(J)
        J[1:(N_neurons+1):N_neurons] = 0.0
        ΔX = 2X - 1 # flip bits in X
        Kfull = exp.(0.5 * (ΔX .* theta - ΔX .* (J * X)))
    end
end
