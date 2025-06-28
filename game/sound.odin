package game

SoundOutputBuffer :: struct {
	samples:            [^]i16,
	samples_per_second: u32,
	sample_count:       u32,
}
