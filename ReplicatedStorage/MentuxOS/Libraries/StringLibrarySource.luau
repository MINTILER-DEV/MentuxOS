return {
	charAt = [[
let value = "";
if argc() >= 1 {
	value = argv(1);
}

let index = 1;
if argc() >= 2 {
	index = toNumber(argv(2));
}
if index < 1 {
	index = 1;
}

libReturn(charAt(value, index));
]],
	concat = [[
let left = "";
let right = "";
if argc() >= 1 {
	left = argv(1);
}
if argc() >= 2 {
	right = argv(2);
}

libReturn(left + right);
]],
	substr = [[
let value = "";
if argc() >= 1 {
	value = argv(1);
}

let startIndex = 1;
if argc() >= 2 {
	startIndex = toNumber(argv(2));
}
if startIndex < 1 {
	startIndex = 1;
}

let valueLength = len(value);
let endIndex = valueLength;
if argc() >= 3 {
	let requestedLength = toNumber(argv(3));
	if requestedLength < 0 {
		requestedLength = 0;
	}
	endIndex = startIndex + requestedLength - 1;
}

let result = "";
let index = startIndex;
while index <= valueLength {
	if index > endIndex {
		index = valueLength + 1;
	} else {
		result = result + charAt(value, index);
		index = index + 1;
	}
}

libReturn(result);
]],
	split = [[
let value = "";
if argc() >= 1 {
	value = argv(1);
}

let delimiter = "";
if argc() >= 2 {
	delimiter = argv(2);
}

let parts = listNew();
if len(delimiter) == 0 {
	push(parts, value);
	libReturn(parts);
}

let current = "";
let index = 1;
let valueLength = len(value);
let delimiterLength = len(delimiter);

while index <= valueLength {
	let matches = true;
	let offset = 1;
	while offset <= delimiterLength {
		if (index + offset - 1) > valueLength {
			matches = false;
		} else {
			if charAt(value, index + offset - 1) != charAt(delimiter, offset) {
				matches = false;
			}
		}
		offset = offset + 1;
	}

	if matches == true {
		push(parts, current);
		current = "";
		index = index + delimiterLength;
	} else {
		current = current + charAt(value, index);
		index = index + 1;
	}
}

push(parts, current);
libReturn(parts);
]],
}
