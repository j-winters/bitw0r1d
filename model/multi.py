"""
Code for running parallelised runs for bitw0r1d using the multiprocessing package.
Please check the number of cpu cores before running!
"""

import multiprocessing as mp
from bitw0r1d import *

# print(mp.cpu_count()) # Uncomment if you do not know the number of cores for your cpu

path="your/path/here/"
printing=False
write=True
limit=10000
generations=10000
s_length=2
s_prob=None
t_length=2
t_prob=None
η_param = [0.01,0.05,0.10,0.20,0.40,0.50,0.60,0.80,0.90,0.95,0.99]
λ_param = [0.01,0.05,0.10,0.20,0.40,0.50,0.60,0.80,0.90,0.95,0.99]
initial_endowment=100.0
p_tradeoff=0.5

if __name__ == '__main__':
	for η in η_param:
		for λ in λ_param:
			print(f'η = {η}   λ = {λ}')
			seeds = seed_gen(1000)
			print(seeds)
			num_processes = mp.cpu_count()
			task_args = [(seed,path,printing,write,limit,generations,s_length,s_prob,t_length,t_prob,η,λ,initial_endowment,p_tradeoff) for seed in seeds]
			pool = mp.Pool(processes=num_processes)
			pool.starmap(simulation, task_args)
			pool.close()
			pool.join()