# bloomfilter

Bloom filters are space-efficient probablistic data structures used to test whether an element
is a member of a set. We will use this set to create a spellchecker.
The source of words are in `dictonary.txt`. It has ~ 339K words.
This is a bloomfilter based spell checker.

P -> Probability of false positives.
Constant :-
N -> Number of items in the filter
You can configure :-
M -> Number of bits in the filter.
K -> Number of hash functions
See ->  https://hur.st/bloomfilter for optimzing the bloomfilter

### Commands

To build bloomfilter: bloomfilter build path_to_dict_src path_to_dict_output M K
To spell check: bloomfilter spell-check path_to_bloom_filter word


For our specific use case ->
N = 338782 (dictonary.txt with 338782 words)
To achieve a P = 0.01 (1 false positive in 100),
Set M=3257969 (397.7KiB)
And K=6

MAX_SIZE of M = 999999999999999
MAX_SIZE of K = 100
