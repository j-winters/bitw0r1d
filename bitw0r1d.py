"""
bitw0r1d v1.0
By James Winters

All code was designed and implemented in Python version 3.1.1
"""

import numpy as np
import pandas as pd
import random as rn
from polyleven import levenshtein as ld

def seed_gen(samples:int,sam_max:int=1000000) -> list:
	"""
	Generates a random seed in range(0, sam_max) for a specified number of samples
	Default for sam_max is 1000000
	"""
	sampling = rn.sample(range(0, sam_max), samples)
	sampling = list(np.unique(sampling))
	while len(sampling) < samples:
		new_samples = rn.sample(range(0, sam_max), samples-len(sampling))
		sampling = list(np.unique(sampling + new_samples))
	return sampling

def string_generator(p:float,l:int) -> str:
	"""
	Generates bitstring of n-length using p (probability of 1) and l (length of string)
	"""
	return ''.join(np.random.choice(['0','1'],l,[p,1-p]))

def evaluate(technologies:str,space:str) -> float:
	"""
	Returns an inverted normalised Levenshtein distance for strings of technologies and search spaces
	"""
	return 1 - ld(technologies,space) / max([len(technologies),len(space)])

def flip(string:str) -> list:
	""" 
	Function to flip a bit to its boolean complement.
	Returns a string that is the same length as input.
	"""
	position = rn.randint(0, len(string) - 1)
	return string[:position] + ('0' if string[position] == '1' else '1') + string[position+1:]

def insert(string:list) -> list:
	""" 
	Function to insert a bit at a random position.
	Returns a string that is of a longer length than the input.
	"""
	position = rn.randint(0, len(string))
	value = '0' if rn.random() < 0.5 else '1'
	return string[:position] + value + string[position:]

def delete(string:list) -> list:
	""" 
	Function to delete a randomly chosen bit from a string.
	Returns a string that is of a shorter length than the input.
	"""
	position = rn.randint(0, len(string) - 1)
	return string[:position] + string[position+1:]

def string_edit(str_1:str, str_2:str, eff:float) -> str:
	"""
	Function for changing string.
	Generates change and returns new string
	"""
	p = rn.random()
	if p < 1/3:  # Modify
		new = flip(str_1)
	elif p < 2/3:  # Expand
		new = insert(str_1)
	else:  # Contract
		if len(str_1) > 1:
			new = delete(str_1)
		else:
			new = str_1 

	# Apply selection logic
	if rn.random() < eff:  # Evaluation is True
		if evaluate(new, str_2) <= evaluate(str_1, str_2):
			return str_1
		else:
			return new
	else:  # No evaluation, always accept
		return new

def resource_function(cS:int,effectiveness:float,cT:int) -> float:
	"""
	Function for producing resources
	Calculates the gains from search spaces (cS * effectiveness)
	And then subtracts losses resulting from any ineffectiveness (cT * ineffectiveness)
	Returns resources
	"""
	return (cS * effectiveness) - (cT * (1 - effectiveness))

def dataframe(data:list) -> pd.DataFrame:
	"""
	Produces a pandas dataframe for writing
	"""
	df = pd.DataFrame(data,columns=[
		'seed',
		'generation',
		'tech_complexity',
		'space_complexity',
		'effectiveness',
		'initial_tech',
		'initial_space',
		'eta',
		'lambda',
		'initial_endowment',
		'p_tradeoff',
		'available_resources',
		'resource_store'
		])
	return df

def writing(df:pd.DataFrame,path:str,seed:int):
	"""
	Writes output to a .csv file
	"""
	df.to_csv(path+f'seed{seed}.csv',mode='a',index=False,header=False)

class Society:
	"""
	Represents a society with technological systems and search spaces that culturally evolve over time.
	
	A society is characterised by:
	- A search space (bitstring) representing the aggregate collection of needs, problems and goals within a society
	- A technological system (bitstring) representing the interdependent repertoire of skills, techniques, artifacts and knowledge available to a society
	- Resource management including initial endowment and depletion tracking
	
	The society can change both its technological systems and search spaces, with resource allocation determining the balance between these two evolutionary processes.
	"""
	def __init__(self, s_length:int, s_prob:float, t_length:int, t_prob:float, initial_endowment:float):
		if s_prob == None:
			s_prob = np.random.uniform(low=0.0,high=1.0,size=None)
		if t_prob == None:
			t_prob = np.random.uniform(low=0.0,high=1.0,size=None)
		# Generating initial search space
		self.space = string_generator(p=s_prob,l=s_length)
		# Generating initial technological system
		self.technologies = string_generator(p=t_prob,l=t_length)
		# Setting the starting resources
		self.resource_store = initial_endowment
		# Setting the resource endowment
		self.initial_endowment = initial_endowment
		# Checks if resources are depleted. Default is set to False
		self.is_depleted = False

	def update_resource_store(self, net_resources:float) -> float:
		"""
		Updates resource store and returns available resources at a given generation.
		If net_resources <= 0, depletes from store.
		If store hits 0, society collapses (absorbing barrier).
		"""
		if net_resources >= 1:
			return net_resources
		else:
			# For resources where the value is between 0 and 1, then have a negative deficit
			if net_resources >= 0:
				deficit = 1
			# Negative resources: draw from store	
			else:
				deficit = abs(net_resources)
			if self.resource_store >= deficit:
				self.resource_store -= deficit
				return 1.0  # Society maintains baseline operations
			else:
				# Store is depleted
				remaining = self.resource_store
				self.resource_store = 0
				self.is_depleted = True
				return remaining  # Final resources before collapse

	def tradeoff(self,iterations:int,p:float) -> list:
		"""
		Tradeoff function for allocation resources
		The number of iterations is determined by the amount of resources
		p corresponds to the probability of allocating resources to two process
		If True: change technological system
		If False: change search space
		"""
		return np.random.choice([True,False],iterations,p=[p,1-p])

	def ce_technologies(self, technologies:str, space:str, η:float) -> str:
		"""
		Process for the cultural evolution of technological systems
		Changes technological system either via stochastic or deterministic process
		The probability of a stochastic or deterministic process is controlled by η
		"""
		new_tech = string_edit(str_1=technologies, str_2=space, eff=η)
		return new_tech

	def ce_space(self, space:str, technologies:str, λ:float) -> str:
		"""
		Process for the cultural evolution of search spaces
		Changes search space either via stochastic or deterministic process
		The probability of a stochastic or deterministic process is controlled by λ
		"""
		new_space = string_edit(str_1=space, str_2=technologies, eff=λ)
		return new_space

def simulation(seed:int, path:str, printing:bool, write:bool, limit:int, generations:int, s_length:int, s_prob:float, t_length:int, t_prob:float, η:float, λ:float, initial_endowment:float, p_tradeoff:float) -> pd.DataFrame:
	"""
	Simulation function for the cultural evolution of technological systems and search spaces.
	
	Parameters:
	-----------
	seed : int
		Random seed for reproducibility
	path : str
		File path for output CSV files
	printing : bool
		Whether to print generation-by-generation progress
	write : bool
		Whether to write results to CSV file
	limit : int
		Upper-limit on technological complexity (terminates if matched or exceeded)
	generations : int
		Maximum number of generations to simulate
	s_length : int
		Initial length of search space bitstring
	s_prob : float
		Initial probability of 1s in search space (None for random)
	t_length : int
		Initial length of technological system bitstring
	t_prob : float
		Initial probability of 1s in technology (None for random)
	η : float
		Eta parameter controlling stochastic vs deterministic tech evolution (0.0-1.0)
	λ : float
		Lambda parameter controlling stochastic vs deterministic space evolution (0.0-1.0)
	initial_endowment : float
		Initial resource endowment for the society
	p_tradeoff : float
		Probability of allocating resources to changing technological system or changing search space
	
	Returns:
	--------
	pd.DataFrame
		Simulation results with columns for seed, generation, complexities, effectiveness, resources, and parameters
		
	Notes:
	------
	The simulation continues until one of three conditions is met:
	1. Maximum generations reached
	2. Resources are depleted (absorbing barrier)
	3. Technological complexity limit exceeded
	"""

	# Set random seeds
	np.random.seed(seed)
	rn.seed(int(seed))

	# Specify empty output list
	output = []

	# Initiate society with initial endowment
	s = Society(s_length=s_length, s_prob=s_prob, t_length=t_length, t_prob=t_prob, initial_endowment=initial_endowment)

	# Generation 0
	# Calculate initial effectiveness
	effectiveness = evaluate(s.technologies, s.space)
	# Get net resources
	net_resources = resource_function(cS=len(s.space), effectiveness=evaluate(s.space, s.technologies), cT=len(s.technologies))
	# Resources available to a society
	available_resources = s.update_resource_store(net_resources)
	# Append to output
	output.append([seed, 0, len(s.technologies), len(s.space), effectiveness, t_length, s_length, η, λ, initial_endowment, p_tradeoff, available_resources, s.resource_store])

	# Generation 1 to generation n
	for gen in range(1, generations):
		# Calculate net resources
		net_resources = resource_function(cS=len(s.space), effectiveness=evaluate(s.space, s.technologies), cT=len(s.technologies))
		# Update store and get available resources
		available_resources = s.update_resource_store(net_resources)
		# Check for depletion (absorbing barrier)
		if s.is_depleted:
			print(f'{seed} depleted resource store at generation {gen}. Final state: tech={len(s.technologies)}, space={len(s.space)}')
			# Generate dataframe
			df = dataframe(data=output)
			# Write to .csv file if True
			if write:
				writing(df=df, path=path, seed=seed)
			return df
		# Determine iterations by rounding available resources
		iterations = round(available_resources) if available_resources >= 1 else 1
		# If there are iterations, then engage in cultural evolutionary dynamics
		if iterations > 0:
			# Get list of evolutionary events: True (change technological system), False (change search space)
			choices = s.tradeoff(iterations=iterations, p=p_tradeoff)
			# For each evolutionary event, make a change to either the technological system or search space
			for choice in choices:
				# Make change to the technological system
				if choice == True:
					s.technologies = s.ce_technologies(technologies=s.technologies, space=s.space, η=η)
				# Make change to the search space
				else:
					s.space = s.ce_space(space=s.space, technologies=s.technologies, λ=λ)
		# Calculate effectiveness
		effectiveness = evaluate(s.technologies, s.space)
		# Append to output
		output.append([seed, gen, len(s.technologies), len(s.space), effectiveness, t_length, s_length, η, λ, initial_endowment, p_tradeoff, available_resources, s.resource_store])
		# Print seed, generation, technological complexity, search space complexity, available resources and effectiveness
		if printing == True:
			print(f'Seed: {seed}   Generation: {gen}   Tech: {len(s.technologies)}   Space: {len(s.space)}  Resources: {available_resources:.2f}   Store: {s.resource_store:.2f}   Effectiveness: {effectiveness:.3f}')
		# Check for complexity upper-limit (if True, end simulation)
		if len(s.technologies) >= limit:
			print(f'{seed} reached complexity limit at generation {gen}')
			df = dataframe(data=output)
			if write:
				writing(df=df, path=path, seed=seed)
			return df
	# End of simulation if at generation 9999
	print(f'Simulation run {seed} complete!')
	df = dataframe(data=output)
	if write:
		writing(df=df, path=path, seed=seed)
	return df

"""
# Example simulation run (uncomment to run)

seed = seed_gen(1)
for seed in seeds:
	simulation(
		seed=seed, # Set seed
		path="/your/path/here/", # Set path
		printing=True, # Print summary output at each generation
		write=False, # Write data to a .csv file
		limit=10000, # Upper-limit of technological complexity for simulation 
		generations=10000, # Total number of generations
		s_length=2, # Initial length of search space
		s_prob=None, # Initial probability of 0s and 1s for search space (default: None)
		t_length=2, # Initial length of technological system
		t_prob=None, # Initial probability of 0s and 1s for technological system (default: None)
		η=0.5, # Eta: Controls probability for type of change to technological systems. Maximally stochastic (η=0.0), Maximally deterministic (η=1.0)
		λ=0.5, # Lambda: Controls probability for type of change to search spaces. Maximally stochastic (λ=0.0), Maximally deterministic (λ=1.0)
		initial_endowment=100.0, # The initial resource endowment for a society (default: 100)
		p_tradeoff=0.5 # Resource allocation tradeoff (default: 0.5)
	)
"""