// Script to log in to YK Pao School Songjiang Campus student WiFi
// SPDX-License-Identifier: BSD-2-Clause

use encoding::hex;
use fmt;
use io;
use memio;
use net::http;
use net::uri;
use os;
use strings;
use time;

fn rc4_hex(plain: str, rc4key: str) (str | nomem) = {
	const pb = strings::toutf8(plain);
	const kb = strings::toutf8(rc4key);

	if (len(kb) == 0) {
		return hex::encodestr(pb)!;
	};

	let sbox: [256]u8 = [0...];
	for (let i = 0z; i < 256z; i += 1) {
		sbox[i] = (i: u8);
	};

	let j: u8 = 0;
	for (let i = 0z; i < 256z; i += 1) {
		let t: uint = (j: uint) + (sbox[i]: uint) + (kb[i % len(kb)]: uint);
		let tmpu: uint = t % 256u;
		j = tmpu: u8;

		const ji = (j: size);
		const tmp = sbox[i];
		sbox[i] = sbox[ji];
		sbox[ji] = tmp;
	};

	let out: []u8 = alloc([0...], len(pb))!;
	defer free(out);

	let a: u8 = 0;
	let b: u8 = 0;

	for (let idx = 0z; idx < len(pb); idx += 1) {
		let au: uint = (a: uint) + 1u;
		au = au % 256u;
		a = au: u8;

		let bu: uint = (b: uint) + (sbox[(a: size)]: uint);
		bu = bu % 256u;
		b = bu: u8;

		const ai = (a: size);
		const bi = (b: size);
		const tmp = sbox[ai];
		sbox[ai] = sbox[bi];
		sbox[bi] = tmp;

		let cu: uint = ((sbox[ai]: uint) + (sbox[bi]: uint)) % 256u;
		const c = cu: u8;

		out[idx] = pb[idx] ^ sbox[(c: size)];
	};

	return hex::encodestr(out)!;
};

fn login(username: str, password: str) os::status = {
	const now = time::now(time::clock::REALTIME);
	const ts = fmt::asprintf("{}", (now.sec * 100): i64)!;
	defer free(ts);

	const pwdhex = rc4_hex(password, ts)!;
	defer free(pwdhex);

	let sink = memio::dynamic();
	defer io::close(&sink)!;

	fmt::fprintf(&sink, "opr=pwdLogin&userName={}&pwd={}&rc4Key={}&auth_tag={}&rememberPwd=1", username, pwdhex, ts, ts)!;

	io::seek(&sink, 0, io::whence::SET)!;

	const client = http::newclient("Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0")!;
	defer http::client_finish(&client);

	const target = match (uri::parse("http://10.2.20.106/ac_portal/login.php")) {
	case let u: uri::uri =>
		yield u;
	case uri::invalid =>
		fmt::errorfln("invalid URI")!;
		return os::status::FAILURE;
	};
	defer uri::finish(&target);

	let req = http::new_request_body(&client, http::POST, &target, &sink)!;
	defer http::request_finish(&req);

	http::header_set(&req.header, "User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0")!;
	http::header_set(&req.header, "Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")!;
	http::header_set(&req.header, "Accept-Language", "en-US,en;q=0.5")!;
	http::header_set(&req.header, "Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")!;
	http::header_set(&req.header, "Origin", "null")!;
	http::header_set(&req.header, "Connection", "keep-alive")!;

	const resp = match (http::do(&client, &req)) {
	case let err: http::error =>
		fmt::errorfln("HTTP error: {}", http::strerror(err))!;
		return os::status::FAILURE;
	case let r: http::response =>
		yield r;
	};
	defer http::response_finish(&resp);

	match (http::check(resp.status)) {
	case let he: http::httperror =>
		fmt::errorfln("server returned error status: {} {}", resp.status, resp.reason)!;
		return os::status::FAILURE;
	case =>
		void;
	};

	fmt::printfln("HTTP/{}.{} {} {}", resp.version.0, resp.version.1, resp.status, resp.reason)!;

	return os::status::SUCCESS;
};

export fn main() void = {
	if (len(os::args) != 3) {
		fmt::errorfln("Usage: {} username passvar", os::args[0])!;
		fmt::errorfln("  username: your YK Pao School username (e.g. s65535)")!;
		fmt::errorfln("  passvar : name of an environment variable containing your password")!;
		os::exit(os::status::FAILURE);
	};

	const username = os::args[1];
	const passvar = os::args[2];

	const password = match (os::getenv(passvar)) {
	case let s: str =>
		yield s;
	case void =>
		fmt::errorfln("{}: environment variable {} does not exist", os::args[0], passvar)!;
		os::exit(os::status::FAILURE);
	};

	os::exit(login(username, password));
};
