import gleam/io

pub fn spell_check(path_to_bloom_filter: String, word: String) {
  io.debug(path_to_bloom_filter)
  io.debug(word)
}
