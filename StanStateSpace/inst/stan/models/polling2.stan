functions {
  #include ssm.stan
}
data {
  int<lower = 1> n;
  int<lower = 1> p;
  vector<lower = 0., upper = 1.>[p] y[n];
  vector<lower = 1.> d[n - 1];
  vector<lower = 0., upper = 0.25>[p] sigma_eps[n];
  int<lower = 0, upper = p> p_t[n];
  int<lower = 0, upper = p> y_idx[n, p];
  int<lower = 1, upper = n>  y_nonmiss;
  int<lower = 1, upper = n> y_nonmiss_t;


  vector<lower = 0.0, uppper = 0.5>[1] a1;
  cov_matrix[1] P1;
  real<lower = 0.> zeta;
  real<lower = 0.> sigma_delta;
}
transformed data {
  // system matrices
  matrix[1, 1] T[1];
  matrix[p, 1] Z[1];
  matrix[p, p] H[n];
  matrix[2, 1] R[1];
  vector[1] c[1];
  int m;
  int q;
  int filter_sz;
  m = 2;
  q = 1;
  c[1] = rep_vector(0., 1);
  Z[1] = rep_matrix(1., p, 1);
  for (t in 1:n) {
    H[t] = diag_matrix(sigma_eps[t] .* sigma_eps[t]);
  }
  for (t in 1:(n - 1)) {
    T[t, 1, 1] = 1.;
    T[t, 1, 2] = 1.;
    T[t, 2, 1] = 0.;
    T[t, 2, 2] = d[t];
  }
  for (t in 1:(n - 1)) {
    R[t, 1, 1] = 0.;
    R[t, 2, 2] = sqrt(d[t]);
  }
  # Calculates the size of the vectors returned by ssm_filter
  filter_sz = ssm_filter_size(1, p);
}
parameters {
  real<lower = 0.> sigma_eta;
  vector<lower = 0.>[y_nonmiss] lambda;
  vector[p - 1] delta;
}
transformed parameters {
  vector[p] d[1];
  matrix[1, 1] Q[t];
  d[1, 1] = 0.;
  d[1, 2:p] = delta;
  // only have positive errors on days with observations
  Q[t] = rep_array(rep_matrix(0., 1, 1), n);
  for (i in 1:y_nonmiss) {
    Q[y_nonomiss_t[i], 1, 1] = pow(sigma_eta * lambda[i], 2);
  }
}
model {
  delta ~ normal(0., sigma_delta);
  sigma_eta ~ cauchy(0., zeta);
  lambda ~ cauchy(0., 1. / n);
  y ~ ssm_miss_lpdf(d, Z, H,
                    c, T, R, Q, a1, P1,
                    p_t, y_idx);
}
generated quantities {
  vector[1] alpha[n];
  {
    vector[filter_sz] filtered[n];
    // filtering
    filtered = ssm_filter_miss(y, d, Z, H, c, T, R, Q,
                               a1, P1, p_t, y_idx);
    // sampling states
    alpha = ssm_simsmo_states_miss_rng(filtered, d, Z, H,
                                       c, T, R, Q,
                                       a1, P1, p_t, y_idx);
  }
}
