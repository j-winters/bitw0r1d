# bitw0r1d: Modelling the emergence of open-ended technological evolution
This repository contains data and code from Winters & Charbonneau (2025). It includes the Python code used for running the model (bitw0r1d), the data generated for Winters & Charbonneau (2025), the R code used for producing the graphs and the supplementary material. 

The top-level folder structure is as follows:

* `analysis/`: Contains R code for producing all graphs and associated summary statistics.
* `data/`:  All data generated for Winters & Charbonneau (2025) in `.csv` format.
* `model/`: The python code for running bitw0r1d. Requires Python 3 with [NumPy](https://numpy.org/), [Pandas](https://pandas.pydata.org/) and [Polyleven](https://pypi.org/project/polyleven/) packages installed.
* `supplementary/`: Data, R code and write up (`supplementary_material.pdf`).

## Running the model
An online version of the simulation is now available here: [bitw0r1d online](https://j-winters.github.io/bitw0r1d/). The actual simulation runs reported in the paper were run in Python 3.1.1 and parallelized using the [multiprocessing](https://docs.python.org/3/library/multiprocessing.html) package. To run the multiprocessing version, go to the file `multi.py`.

Below is a simple version of the model for performing a single run in Python:

```python
>>> import bitw0r1d *
>>> simulation(
      seed=1234,
      path='your/path/here/',
      printing=True,
      write=False,
      limit=10000,
      generations=10000,
      s_length=2,
      s_prob=None,
      c_length=2,
      c_prob=None,
      η=0.5,
      λ=0.5,
      initial_endowment=100,
      p_tradeoff=0.5)
```

The parameters correponds to the following:
* `seed`: The specific simulation run as determined by a seed.
* `path`: File path for writing output (if `write=True`).
* `printing`: Print summary output for each generation.
* `write`: Write data to a `.csv` file.
* `limit`: Upper-limit on the complexity of technological systems. If matched or exceeded, the simulation will terminate.
* `generations`: Number of generations for a given run.
* `s_length`: Initial length of search space.
* `s_prob`: Initial probability of 0s and 1s for generating a search space.
* `c_length`: Initial length of cultural system.
* `c_prob`: Initial probability of 0s and 1s for generating a cultural system.
* `η`: Controls probability for type of change to cultural systems. Maximally stochastic (`η=0.0`), Maximally deterministic (`η=1.0`)
* `λ`: Controls probability for type of change to search spaces. Maximally stochastic (`λ=0.0`), Maximally deterministic (`λ=1.0`)
* `initial_endowment`: The initial resource endowment for a society.
* `p_tradeoff`: Resource allocation tradeoff for making changes to cultural systems or search spaces.
