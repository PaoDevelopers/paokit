use fmt;
use getopt;
use io;
use net;
use net::ip;
use net::tcp;
use os;
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

export fn main() void = {
	let opt_file: (str | void) = void;
	let opt_user: (str | void) = void;
	let opt_pass: (str | void) = void;
	let opt_addr: str = "10.2.20.170";
	let opt_queue: str = "sjbw";
	let opt_port: u16 = 515;

	const cmd = getopt::parse(os::args,
		"YK Pao School (Songjiang Campus) print client",
		('f', "file", "file to print (required)"),
		('u', "user", "username (required)"),
		('p', "pass", "password (required)"),
		('a', "addr", "printer address"),
		('P', "port", "printer port"),
		('q', "queue", "printer queue"),
	);
	defer getopt::finish(&cmd);

	for (let opt .. cmd.opts) {
		switch (opt.0) {
		case 'f' =>
			opt_file = opt.1;
		case 'u' =>
			opt_user = opt.1;
		case 'p' =>
			opt_pass = opt.1;
		case 'a' =>
			opt_addr = opt.1;
		case 'q' =>
			opt_queue = opt.1;
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
		fmt::fatal("Provide -f <opt_file>");
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

	const sys_uid = unix::getuid();
	const sys_username = unix::

	const st = os::stat(path)!;
	const file_size = st.sz;
	const src = os::open(path)!;
	defer io::close(src)!;

	const addr = ip::parse(CONFIG_HOST)!;
	const sock = tcp::connect(addr, CONFIG_PORT)!;
	defer net::close(sock)!;

	{
		const line = strings::concat("\x02", CONFIG_QUEUE, "\n")!;
		defer free(line);
		io::writeall(sock, strings::toutf8(line))!;
		expect_ack(sock, "after queue select");
	};

	const dfname = strings::concat("dfA", CONFIG_JOB_NUMBER, os::hostname())!;
	defer free(dfname);
	const cfname = strings::concat("cfA", CONFIG_JOB_NUMBER, os::hostname())!;
	defer free(cfname);

	{
		const ctrl = strings::concat(
			"H", os::hostname(), "\n",
			"P", sys_username, "\n",
			"l", dfname, "\n",
			"J", jobname, "\n",
			"U", dfname, "\n",
			"N", jobname, "\n",
		)!;
		defer free(ctrl);

		{
			const suffix = strings::concat(" ", cfname, "\n")!;
			defer free(suffix);

			const ctrl_len = len(strings::toutf8(ctrl));
			const header = fmt::asprintf("{}{}{}", "\x02", ctrl_len, suffix)!;
			defer free(header);

			io::writeall(sock, strings::toutf8(header))!;
			expect_ack(sock, "after control header");
		};

		{
			io::writeall(sock, strings::toutf8(ctrl))!;
			io::writeall(sock, NUL[..])!;
			expect_ack(sock, "after control body");
		};
	};

	let auth_password_crypt = strings::fromutf8_unsafe(pw_encode(strings::toutf8(auth_password))!);

	let pjl_header = fmt::asprintf("@PJL SET STRINGCODESET=UTF8\n@PJL JOB MODE=PRINTER\r\n@PJL SET JOBATTR=\"@CNAM={}\"\n@PJL SET JOBATTR=\"@LUNA={}\"\n@PJL SET JOBATTR=\"@HOAD=I0A02BCE5\"\n@PJL SET JOBATTR=\"@NLPP=1\"\n@PJL SET JOBATTR=\"@JOAU={}\"\r\n@PJL SET JOBATTR=\"@JOEP={}\"\r\n@PJL SET JOBATTR=\"@DAID=\"\r\n@PJL SET JOBATTR=\"@ACNA={}\"\r\n@PJL SET JOBATTR=\"@DIND=PORTRAIT\"\n@PJL SET RENDERMODE=COLOR\n@PJL COMMENT FXJOBINFO VERSION=1.5.0\n@PJL COMMENT FXJOBINFO BEGIN\n@PJL COMMENT FXJOBINFO PDLTYPE=PDL[POSTSCRIPT]:VERSION[3]\n@PJL COMMENT FXJOBINFO JOBTYPE=PRINT\n@PJL COMMENT FXJOBINFO JOBCOPIES=1\n@PJL COMMENT FXJOBINFO PAGECOPIES=1\n@PJL COMMENT FXJOBINFO DUPLEXTYPE=DUPLEX\n@PJL COMMENT FXJOBINFO COLORMODE=COLOR\n@PJL COMMENT FXJOBINFO NUP=1\n@PJL COMMENT FXJOBINFO STAPLE=OFF\n@PJL COMMENT FXJOBINFO ORIENTATION=PORTRAIT\n@PJL COMMENT FXJOBINFO MIXEDSIZETYPE=NONE\n@PJL COMMENT FXJOBINFO CUD=OFF\n@PJL COMMENT FXJOBINFO END\n@PJL ENTER LANGUAGE=POSTSCRIPT\n", CONFIG_HOSTNAME, sys_username, auth_username, auth_password_crypt, jobname)!;
	defer free(pjl_header);

	{
		const suffix = strings::concat(" ", dfname, "\n")!;
		defer free(suffix);

		const line = fmt::asprintf("{}{}{}{}", "\x03", file_size + len("\x1B%-12345X") + len("\x04\x1B%-12345X@PJL EOJ\n") + len(pjl_header), suffix, "\x1B%-12345X")!;
		defer free(line);

		io::writeall(sock, strings::toutf8(line))!;
		expect_ack(sock, "after data receive line");
	};

	{
		io::writeall(sock, strings::toutf8(pjl_header))!;
	};

	{
		const copied = io::copy(sock, src)!;
		if (copied != file_size) {
			fmt::fatalf("Short write: copied {} of {} bytes", copied, file_size);
		};

		io::writeall(sock, strings::toutf8("\x04\x1B%-12345X@PJL EOJ\n"))!;
		io::writeall(sock, NUL[..])!;
		expect_ack(sock, "after sending data");
	};
};
