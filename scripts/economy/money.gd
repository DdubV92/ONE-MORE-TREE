class_name Money
extends RefCounted
## Money is always integer cents. Formatting only; never float arithmetic.


static func format_cents(cents: int) -> String:
	var neg := cents < 0
	var c := absi(cents)
	var dollars := c / 100
	var rest := c % 100
	var ds := str(dollars)
	var grouped := ""
	while ds.length() > 3:
		grouped = "," + ds.substr(ds.length() - 3) + grouped
		ds = ds.substr(0, ds.length() - 3)
	return ("-" if neg else "") + ds + grouped + ".%02d" % rest
