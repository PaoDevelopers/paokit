use fmt;
use strings;
use encoding::base64;

// Encodes a plaintext PowerSchool password into the insecure "encrypted"-ish
// format required by the printer API. The output is allocated and must be freed
// by the caller.
fn pw_encode(password: []u8) ([]u8 | nomem) = {
	let pwlen: size = if (len(password) < 12) {
		yield len(password);
	} else {
		yield 12;
	};
	password = password[..pwlen];

	let buf: []u8 = alloc(password...)?;
	defer free(buf);

	const xorkey: [12]u8 = ['p', 'f', 's', 'w', 'p', 'f', 's', 'w', 'p', 'f', 's', 'w'];

	for (let i = 0z; i < len(buf); i += 1) {
		buf[i] = buf[i] ^ xorkey[i];
	};

	let out = base64::encodeslice(&base64::std_encoding, buf)?;

	return out;
};
