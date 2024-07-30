import argv
import gleam/io

import build_filter
import spell_check

pub fn main() {
  case argv.load().arguments {
    ["build", path_to_dict_src, path_to_dict_output, m, k] -> {
      build_filter.build_bloomfilter(
        path_to_dict_src,
        path_to_dict_output,
        m,
        k,
      )
      io.println("SUCESS")
    }
    ["spell-check", path_to_bloom_filter, word] -> {
      spell_check.spell_check(path_to_bloom_filter, word)
      io.println("SUCESS")
    }
    _ -> {
      io.println(
        "To build bloomfilter: bloomfilter build path_to_dict_src path_to_dict_output m k
         To spell check: bloomfilter spell-check path_to_bloom_filter word

         m = Number of bits in the filter
         k = Number of hash functions
        ",
      )
    }
  }
}
