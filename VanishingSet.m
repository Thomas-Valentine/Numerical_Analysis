% ---VanishingSet.m-------------------------------------------------- %

% ---INFORMATION----------------------------------------------------- %
% REFERENCE: Telen, S., Van Barel, M. A stabilized normal form
% algorithm for generic systems of polynomial equations. Journal of
% Computational and Applied Mathematics volume 342, pages 119–132,
% 2017. https://doi.org/10.1016/j.cam.2018.04.021
%
% This program generates n random polynomials f1,f2,...,fn with n
% variables. It then finds the normal forms of monomials with respect
% to a basis of the quotient ring C[x1,x2,...xn]/I, where I is the
% ideal generated by f1,f2,...,fn. It uses these normal forms to
% compute certain multiplication matrices, the eigenvalues of which
% are then used to find the vanishing set for f1,f2,...,fn. The error
% is given for this solution.
% ------------------------------------------------------------------- %

% ---INPUTS---------------------------------------------------------- %
n = 3; d = 2*ones(n,1);
f = GenerateRandomPolynomials(n,d);
% n is number of polynomials and the number of variables.
% d is a column vector of the degrees of each polynomial.
% f is n polynomials. row i is the coefficients of fi, for 1<=i<=n.
% The remaining n rows determine the monomial for each coefficient.
% Example: Let f1 = 2 - x + x^2 - 2y^2, and f2 = y - x^2 + xy.
% Then n = 2, d = [2;2], and
% f = 2 -1  0  1  0 -2
%     0  0  1 -1  1  0
%     0  1  0  2  1  0
%     0  0  1  0  1  2
% ------------------------------------------------------------------- %

% ---EXECUTION------------------------------------------------------- %
[M,S] = MacaulayMatrix(f,n,d);
% M is the Macaulay matrix M with respect to polynomials f.
% S is the Monomials corresponding to columns of M.
[N,S,B] = SolveMatrix(M,S,n,d);
% B is the basis chosen.
% N is the normal forms of S with respect to B, given by solving M.
X = FindMultiplicationMatrices(N,S,B,n);
% X is the multiplication matrices computed from N.
[E,r] = FindVanishingSet(X,f,n,d);
% P is the vanishing set of polynomials f, r is the error.
% ------------------------------------------------------------------- %

% ---OUTPUT---------------------------------------------------------- %
disp(E);
disp(r);
% ------------------------------------------------------------------- %

% ---MAIN-FUNCTIONS-------------------------------------------------- %
function f = GenerateRandomPolynomials(n,d)
    % input: degrees d, size n.
    % output: polynomials f.
    d0 = max(d);
    f = zeros(2*n,nchoosek(d0 + n,n));
    for i = 1:n
        for j = 1:nchoosek(d(i,1) + n,n)
            f(i,j) = randn;
            % normally distributed coefficients, mean 0, std 1.
        end
    end
    f(n+1:2*n,:) = IGLOrdering(n,d0); % monomials for each coefficient.
end

function [M,S] = MacaulayMatrix(f,n,d)
    % input: polynomials f, size n, degrees d.
    % output: Macaulay matrix M, column monomials S in graded
    % lexicographic order. Entry [:,q] = [i;j;...] in S refers to
    % monomial x^(i)y^(j)..., which corresponds to column q in M.
    d0 = max(d);
    t = prod(d) - n + 1; % highest degree of monomials in M.
    S = GLOrdering(n,t);
    % S is the set of monomials corresponding to columns
    % of M, which is all monomials of degree at most t.
    a = 0;
    for i = 1:n
        a = a + nchoosek(t-d(i,1)+n,n);
    end
    M = zeros(a,nchoosek(t+n,n)); % Macaulay matrix.
    m = 1;
    for i = 1:n % for each polynomial fi,
        B = IGLOrdering(n,t-d(i,1));
        % B is the set of monomials to be multiplied with fi.
        for j = 1:size(B,2) % for each monomial multiplier,
            for k = 1:nchoosek(d(i,1) + n,n) % for each monomial in fi
                Bf = f(n+1:end,k)+B(:,j);
                % Bf is the kth monomial of Bj*fi.
                a = ColumnIndex(S,Bf); % index of Bf in S.
                M(m,a) = f(i,k);
                % assign corresponding coefficient.
            end
            m = m + 1; % increment row counter.
        end
    end
end

function [N,S,B] = SolveMatrix(M,S,n,d)
    % input: Macaulay matrix M, column monomials S, size n, degrees d.
    % output: basis B, a subset of S. Normal forms N.
    t = prod(d) - n + 1; % highest degree of monomials in M.
    M_t_size = 0; % width of M_t.
    i = 1;
    while sum(S(:,i)) == t
        M_t_size = M_t_size + 1; i = i + 1;
    end
    M_t = M(:,1:M_t_size);
    % M_t is the submatrix corresponding to monomials of degree t.
    [Q_t,R_t] = qr(M_t); % QR factorisation of M_t.
    M = Q_t'*M; % Apply unitary matrix.
    M_star = M(M_t_size + 1:end,M_t_size + 1:end);
    % M_star is the lower right block which is not triangular.
    [star_height,star_width] = size(M_star); % size of M_star.
    [Q,R,P] = qr(M_star); % QR factorisation of M_star.
    O = zeros(M_t_size,star_width);
    M = M*([eye(M_t_size), O; O', P]); % permute M.
    S = S*([eye(M_t_size), O; O', P]);
    O = zeros(M_t_size,star_height);
    M = ([eye(M_t_size), O; O', Q'])*M; % make M triangular.
    B_size = prod(d); % size of the basis assuming genericity.
    B = S(:,end-B_size+1:end); % basis monomials.
    M_height = size(S,2) - B_size; % number of rows in M.
    N = zeros(M_height,size(B,2)); % normal forms.
    for i = 1:size(B,2)
        N(:,i) = -M(1:M_height,1:M_height)\M(1:M_height,M_height+i);
    end
    N = [N; eye(B_size)];
end

function [N,S,B] = SolveMatrixNew(M,S,n,d)
    % NOTE: This function can only be used when n = 2, and all
    % degrees are the same. It is an optimisation of SolveMatrix().

    % input: Macaulay matrix M, column monomials S, size n, degree d.
    % output: basis B, a subset of S. Normal forms N.
    t = prod(d) - n + 1; % highest degree of monomials in M.
    M_t_size = 0; % width of M_t.
    i = 1;
    while sum(S(:,i)) == t
        M_t_size = M_t_size + 1; i = i + 1;
    end
    a = 1:1:t+1; b = []; % indices for columns in M_t.
    for i = t+2:size(M,2)
        % append indices of every column meeting boundary conditions.
        if v(S(1,i),S(2,i),d(1,1),t) >= eta(d(1,1))
            a(1,end+1) = i;
            M_t_size = M_t_size + 1;
        else
            b(1,end+1) = i;
        end
    end
    M_t = M(:,a);
    S_t = S(:,a);
    % submatrix corresponding to monomials
    % guaranteed to not be in the basis.
    M_s = M(:,b);
    S_s = S(:,b);
    % submatrix corresponding to monomials possibly in the basis.
    M = [M_t M_s];
    S = [S_t S_s];
    [Q_t,R_t] = qr(M_t); % QR factorisation of M_t.
    M = Q_t'*M; % Apply unitary matrix.
    M_star = M(M_t_size + 1:end,M_t_size + 1:end);
    % M_star is the lower right block which is not triangular.
    [star_height,star_width] = size(M_star); % size of M_star.
    [Q,R,P] = qr(M_star); % QR factorisation of M_star
    O = zeros(M_t_size,star_width);
    M = M*([eye(M_t_size), O; O', P]); % permute M.
    S = S*([eye(M_t_size), O; O', P]);
    O = zeros(M_t_size,star_height);
    M = ([eye(M_t_size), O; O', Q'])*M; % make M triangular.
    M_height = size(M,1); % number of rows in M.
    B = S(:,M_height + 1:end); % basis monomials.
    N = zeros(M_height,size(B,2)); % normal forms.
    for i = 1:size(B,2)
        N(:,i) = -M(:,1:M_height)\M(:,M_height+i);
    end
    N = [N; eye(B_size)];
end

function X = FindMultiplicationMatrices(N,S,B,n)
    % input: normal forms N, basis B, monomials S.
    % output: multiplication matrices X.
    [a,b] = size(N); % b is basis size, a is size of S.
    X = zeros(b,b,n); % multiplication matrices
    I = eye(n); % identity matrix
    for t = 1:n % compute multiplication matrices for each variable
        for i = 1:b % for each basis monomial m
            for j = 1:a % find basis monomial multiplied by variable
                if S(:,j) == B(:,i) + I(:,t)
                    X(:,i,t) = N(j,:)'; % add column to matrix
                    break
                end
            end
        end
    end
end

function [V,r] = FindVanishingSet(X,f,n,d)
    % input: multiplication matrices X, size n, degrees d.
    % output: vanishing set P
    V = zeros(prod(d),n); % vanishing set, each row is a point.
    [E,D] = eig(X(:,:,1));
    V(:,1) = diag(D); % each matrix gives a coordinate.
    for t = 2:n
        for i = 1:prod(d)
            x = X(:,:,t)*E(:,i); y = E(:,i);
            V(i,t) = x(1,1)/y(1,1);
            % each point must correspond to the same eigenvector.
        end
    end
    r = CheckSolution(V,f,n,d);
end
% ------------------------------------------------------------------- %

% ---SUPPORTING-FUNCTIONS-------------------------------------------- %
function out = GLOrdering(n,d0)
    % input: number of variables n, maximum degree d.
    % output: Column vectors corresponding to monomials in graded
    % lexicographic order. [i;j;...] corresponds to x^(i)y^(j)...
    % Starting at degree d.
    out = zeros(n,nchoosek(d0 + n,n));
    m = 1; d = d0;
    while d >= 0
        out(1,m) = d; m = m + 1;
        while out(n,m-1) < d
            i = n - 1;
            while out(i,m-1) == 0
                i = i - 1;
            end
            if i > 1
                out(1:i-1,m) = out(1:i-1,m-1);
            end
            out(i,m) = out(i,m-1) - 1;
            if i < n-1
                out(i+1,m) = out(i+1,m-1) + sum(out(i+2:end,m-1)) + 1;
                out(i+2:end,m) = zeros(n-i-1,1);
            else
                out(i+1,m) = out(i+1,m-1) + 1;
            end
            m = m + 1;
        end
        d = d-1;
    end
end

function out = IGLOrdering(n,d0)
    % input: number of variables n, maximum degree d.
    % output: Vectors corresponding to monomials in inverse graded
    % lexicographic order. [i;j;...] corresponds to x^(i)y^(j)...
    % Starting at degree 0.
    out = zeros(n,nchoosek(d0 + n,n));
    m = 1; d = 0;
    while d <= d0
        out(1,m) = d; m = m + 1;
        while out(n,m-1) < d
            i = n - 1;
            while out(i,m-1) == 0
                i = i - 1;
            end
            if i > 1
                out(1:i-1,m) = out(1:i-1,m-1);
            end
            out(i,m) = out(i,m-1) - 1;
            if i < n-1
                out(i+1,m) = out(i+1,m-1) + sum(out(i+2:end,m-1)) + 1;
                out(i+2:end,m) = zeros(n-i-1,1);
            else
                out(i+1,m) = out(i+1,m-1) + 1;
            end
            m = m + 1;
        end
        d = d+1;
    end
end

function out = ColumnIndex(S,V)
    % input: matrix S, column V.
    % output: index of first column V in S, 0 if not found.
    out = 0;
    for i = 1:size(S,2)
        if S(:,i) == V
            out = i; break
        end
    end
end

function out = v(i,j,d,t)
    % input: x power i, y power j, system degree d, resulting t.
    % output: number of nonzero entries in column of M corresponding
    % to monomial x^(i)y^(j) when n = 2.
    if i+j<d
        out = 2*(i+1)*(j+1);
    elseif i>=t-d
        out = 2*(1-i-j+t)*(j+1);
    elseif j>=t-d
        out = 2*(1-i-j+t)*(i+1);
    else
        out = 2*(i+1)*(j+1) - 2*(i+j-d+1)^2;
    end
end

function out = eta(d)
    % input: system degree d.
    % output: minimum threshold for v_(i,j) to exclude x^(i)y^(j)
    % from basis choice when n = 2.
    out = (d^2)/3 + 3*d + 90;
end

function out = CheckSolution(P,f,n,d)
    % input: vanishing set P, polynomials f, size n, degrees d.
    % output: error of P, measured as the sum of outputs of each
    % polynomial with each point in P as input.
    out = 0;
    d0 = max(d);
    for i = 1:n
        for j = 1:prod(d)
            s = 0;
            for k = 1:nchoosek(d0 + n,n)
                s = s + (f(i,k)*prod((P(j,:)').^f(n+1:end,k)));
            end
            s = abs(s); out = out + s;
        end
    end
end
% ------------------------------------------------------------------- %

% ---END------------------------------------------------------------- %
