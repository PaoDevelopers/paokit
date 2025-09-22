use fmt;
use getopt;
use io;
use net;
use net::ip;
use net::tcp;
use os;
use strconv;
use strings;

def CONFIG_JOB_NUMBER: str = "985";

const NUL: [1]u8 = [0u8];

fn expect_ack(h: io::handle, ctx: str) void = {
	let b: [1]u8 = [0u8];
	match (io::read(h, b[..])) {
	case let n: size =>
		if (n != 1) fmt::fatalf("{}: expected 1-byte ACK", ctx);
	case io::EOF =>
		fmt::fatalf("{}: disconnected waiting for ACK", ctx);
	case let err: io::error =>
		fmt::fatalf("{}: {}", ctx, io::strerror(err));
	};
	if (b[0] != 0u8) {
		fmt::fatalf("{}: job rejected", ctx);
	};
};

fn resolve_user(fallback: str) str = {
	return os::tryenv("USER", fallback);
};

export fn main() void = {
	let opt_file: (str | void) = void;
	let opt_user: (str | void) = void;
	let opt_pass: (str | void) = void;
	let opt_addr: str = "10.2.20.170";
	let opt_queue: str = "sjbw";
	let opt_port: u16 = 515;
	let opt_staple: (str | void) = void;
	let debug_mode: bool = false;

	const cmd = getopt::parse(os::args,
		"LPD/PJL print client",
		('d', "debug: read acks from stdin, write stream to stdout"),
		('f', "file", "file to print (required)"),
		('u', "user", "username (required)"),
		('p', "pass", "password (required)"),
		('a', "addr", "printer address"),
		('P', "port", "printer port"),
	);
	defer getopt::finish(&cmd);

	for (let opt .. cmd.opts) {
		switch (opt.0) {
		case 'd' =>
			debug_mode = true;
		case 'f' =>
			opt_file = opt.1;
		case 'u' =>
			opt_user = opt.1;
		case 'p' =>
			opt_pass = opt.1;
		case 'a' =>
			opt_addr = opt.1;
		case 'P' =>
			opt_port = strconv::stou16(opt.1)!;
		case =>
			abort();
		};
	};

	const path = match (opt_file) {
	case let s: str =>
		yield s;
	case =>
		fmt::fatal("Provide -f <file>");
	};
	const jobname = path;

	let auth_username = match (opt_user) {
	case let s: str =>
		yield s;
	case =>
		fmt::fatal("Provide -u <username>");
	};
	let auth_password = match (opt_pass) {
	case let s: str =>
		yield s;
	case =>
		fmt::fatal("Provide -p <password>");
	};

	const hostname = os::hostname();
	let sys_username = resolve_user(auth_username);

	const st = os::stat(path)!;
	const file_size = st.sz;
	const src = os::open(path)!;
	defer io::close(src)!;

	let rd: io::handle = os::stdin;
	let wr: io::handle = os::stdout;
	let sock: (net::socket | void) = void;

	if (!debug_mode) {
		const ipaddr = ip::parse(opt_addr)!;
		const s = tcp::connect(ipaddr, opt_port)!;
		sock = s;
		rd = s;
		wr = s;
	};

	{
		const line = strings::concat("\x02", opt_queue, "\n")!;
		defer free(line);
		io::writeall(wr, strings::toutf8(line))!;
		expect_ack(rd, "after queue select");
	};

	const dfname = strings::concat("dfA", CONFIG_JOB_NUMBER, hostname)!;
	defer free(dfname);
	const cfname = strings::concat("cfA", CONFIG_JOB_NUMBER, hostname)!;
	defer free(cfname);

	{
		const ctrl = strings::concat(
			"H", hostname, "\n",
			"P", sys_username, "\n",
			"l", dfname, "\n",
			"J", jobname, "\n",
			"U", dfname, "\n",
			"N", jobname, "\n",
		)!;
		defer free(ctrl);

		const ctrl_len = len(strings::toutf8(ctrl));
		const suffix = strings::concat(" ", cfname, "\n")!;
		defer free(suffix);
		const header = fmt::asprintf("{}{}{}", "\x02", ctrl_len, suffix)!;
		defer free(header);

		io::writeall(wr, strings::toutf8(header))!;
		expect_ack(rd, "after control header");

		io::writeall(wr, strings::toutf8(ctrl))!;
		io::writeall(wr, NUL[..])!;
		expect_ack(rd, "after control body");
	};

	let auth_password_crypt = strings::fromutf8_unsafe(
		pw_encode(strings::toutf8(auth_password))!
	);

	let staple_header: str = fmt::asprintf(
		"@PJL COMMENT FXJOBINFO STAPLE=OFF\r\n"
	)!;
	defer free(staple_header);

	let pjl_header_part = fmt::asprintf(
		"@PJL SET STRINGCODESET=UTF8\r\n"
		"@PJL JOB MODE=PRINTER\r\n"
		"@PJL SET JOBATTR=\"@CNAM={}\"\r\n"
		"@PJL SET JOBATTR=\"@LUNA={}\"\r\n"
		"@PJL SET JOBATTR=\"@HOAD=I0A02BCE5\"\r\n"
		"@PJL SET JOBATTR=\"@NLPP=1\"\r\n"
		"@PJL SET JOBATTR=\"@JOAU={}\"\r\n"
		"@PJL SET JOBATTR=\"@JOEP={}\"\r\n"
		"@PJL SET JOBATTR=\"@DAID=\"\r\n"
		"@PJL SET JOBATTR=\"@ACNA={}\"\r\n"
		"@PJL SET JOBATTR=\"@DIND=PORTRAIT\"\r\n"
		"@PJL SET RENDERMODE=COLOR\r\n"
		"@PJL COMMENT FXJOBINFO VERSION=1.5.0\r\n"
		"@PJL COMMENT FXJOBINFO BEGIN\r\n"
		"@PJL COMMENT FXJOBINFO PDLTYPE=PDL[POSTSCRIPT]:VERSION[3]\r\n"
		"@PJL COMMENT FXJOBINFO JOBTYPE=PRINT\r\n"
		"@PJL COMMENT FXJOBINFO JOBCOPIES=1\r\n"
		"@PJL COMMENT FXJOBINFO PAGECOPIES=1\r\n"
		"@PJL COMMENT FXJOBINFO DUPLEXTYPE=DUPLEX\r\n"
		"@PJL COMMENT FXJOBINFO COLORMODE=COLOR\r\n"
		"@PJL COMMENT FXJOBINFO NUP=1\r\n"
		"@PJL COMMENT FXJOBINFO ORIENTATION=PORTRAIT\r\n"
		"@PJL COMMENT FXJOBINFO MIXEDSIZETYPE=NONE\r\n"
		"@PJL COMMENT FXJOBINFO CUD=OFF\r\n"
		"@PJL COMMENT FXJOBINFO END\r\n"
		"@PJL ENTER LANGUAGE=POSTSCRIPT\r\n",
		hostname, sys_username,
		auth_username, auth_password_crypt, jobname,
	)!;
	defer free(pjl_header_part);

	let pjl_header = strings::concat(staple_header, pjl_header_part)!;
	defer free(pjl_header);

	{
		const suffix = strings::concat(" ", dfname, "\n")!;
		defer free(suffix);

		const pre_len = len(strings::toutf8(pjl_header));
		const post_len = len(strings::toutf8("\x04\x1B%-12345X@PJL EOJ\n"));
		const total = file_size + pre_len + post_len + len("\x1B%-12345X");

		const line = fmt::asprintf("{}{}{}{}", "\x03", total, suffix, "\x1B%-12345X")!;
		defer free(line);

		io::writeall(wr, strings::toutf8(line))!;
		expect_ack(rd, "after data receive line");
	};

	io::writeall(wr, strings::toutf8(pjl_header))!;

	{
		const copied = io::copy(wr, src)!;
		if (copied != file_size) {
			fmt::fatalf("Short write: copied {} of {} bytes", copied, file_size);
		};
	};

	io::writeall(wr, strings::toutf8("\x04\x1B%-12345X@PJL EOJ\n"))!;
	io::writeall(wr, NUL[..])!;
	expect_ack(rd, "after sending data");

	match (sock) {
	case let s: net::socket =>
		net::close(s)!;
	case =>
		void;
	};
};
