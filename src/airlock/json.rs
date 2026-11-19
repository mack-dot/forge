//! Strict JSON parser of the airlock engine. NATIVE CHECK, not proved. Standard library only.
//! RFC 8259 grammar. Refused: duplicate keys in one object (compared after unescaping), a lone surrogate,
//! a raw control byte in a string, trailing bytes, nesting deeper than MAX_DEPTH. Numbers are kept as their text.
use std::collections::HashSet;

const MAX_DEPTH: usize = 64;

#[derive(Debug, Clone, PartialEq)]
pub enum J {
    Null,
    Bool(bool),
    Num(String),
    Str(String),
    Arr(Vec<J>),
    Obj(Vec<(String, J)>),
}

impl J {
    /// The value of `key` in an object, or None.
    pub fn get(&self, key: &str) -> Option<&J> {
        match self {
            J::Obj(fields) => fields.iter().find(|(k, _)| k == key).map(|(_, v)| v),
            _ => None,
        }
    }
}

pub fn parse(text: &str) -> Result<J, &'static str> {
    let mut p = P { t: text, b: text.as_bytes(), i: 0 };
    p.ws();
    let v = p.value(0)?;
    p.ws();
    if p.i != p.b.len() {
        return Err("TRAILING_BYTES");
    }
    Ok(v)
}

struct P<'a> {
    t: &'a str,
    b: &'a [u8],
    i: usize,
}

impl<'a> P<'a> {
    fn ws(&mut self) {
        while self.i < self.b.len() && matches!(self.b[self.i], b' ' | b'\t' | b'\n' | b'\r') {
            self.i += 1;
        }
    }
    fn peek(&self) -> Option<u8> {
        self.b.get(self.i).copied()
    }
    fn lit(&mut self, s: &str, v: J) -> Result<J, &'static str> {
        if self.b[self.i..].starts_with(s.as_bytes()) {
            self.i += s.len();
            Ok(v)
        } else {
            Err("BAD_LITERAL")
        }
    }
    fn value(&mut self, depth: usize) -> Result<J, &'static str> {
        if depth > MAX_DEPTH {
            return Err("TOO_DEEP");
        }
        match self.peek() {
            Some(b'{') => self.object(depth),
            Some(b'[') => self.array(depth),
            Some(b'"') => Ok(J::Str(self.string()?)),
            Some(b't') => self.lit("true", J::Bool(true)),
            Some(b'f') => self.lit("false", J::Bool(false)),
            Some(b'n') => self.lit("null", J::Null),
            Some(b'-' | b'0'..=b'9') => self.number(),
            _ => Err("BAD_VALUE"),
        }
    }
    fn object(&mut self, depth: usize) -> Result<J, &'static str> {
        self.i += 1;
        let (mut fields, mut seen) = (Vec::new(), HashSet::new());
        self.ws();
        if self.peek() == Some(b'}') {
            self.i += 1;
            return Ok(J::Obj(fields));
        }
        loop {
            self.ws();
            if self.peek() != Some(b'"') {
                return Err("BAD_KEY");
            }
            let key = self.string()?;
            self.ws();
            if self.peek() != Some(b':') {
                return Err("NO_COLON");
            }
            self.i += 1;
            self.ws();
            let v = self.value(depth + 1)?;
            if !seen.insert(key.clone()) {
                return Err("DUPLICATE_KEY");
            }
            fields.push((key, v));
            self.ws();
            match self.peek() {
                Some(b',') => self.i += 1,
                Some(b'}') => {
                    self.i += 1;
                    return Ok(J::Obj(fields));
                }
                _ => return Err("BAD_OBJECT"),
            }
        }
    }
    fn array(&mut self, depth: usize) -> Result<J, &'static str> {
        self.i += 1;
        let mut items = Vec::new();
        self.ws();
        if self.peek() == Some(b']') {
            self.i += 1;
            return Ok(J::Arr(items));
        }
        loop {
            self.ws();
            items.push(self.value(depth + 1)?);
            self.ws();
            match self.peek() {
                Some(b',') => self.i += 1,
                Some(b']') => {
                    self.i += 1;
                    return Ok(J::Arr(items));
                }
                _ => return Err("BAD_ARRAY"),
            }
        }
    }
    fn hex4(&mut self) -> Result<u32, &'static str> {
        let s = self.t.get(self.i..self.i + 4).ok_or("BAD_ESCAPE")?;
        if !s.bytes().all(|c| c.is_ascii_hexdigit()) {
            return Err("BAD_ESCAPE");
        }
        self.i += 4;
        u32::from_str_radix(s, 16).map_err(|_| "BAD_ESCAPE")
    }
    fn string(&mut self) -> Result<String, &'static str> {
        self.i += 1; // the opening quote
        let mut s = String::new();
        loop {
            let start = self.i;
            while self.i < self.b.len() && !matches!(self.b[self.i], b'"' | b'\\' | 0..=0x1f) {
                self.i += 1;
            }
            s.push_str(&self.t[start..self.i]); // the run ends at an ASCII byte: a char boundary
            match self.peek() {
                Some(b'"') => {
                    self.i += 1;
                    return Ok(s);
                }
                Some(b'\\') => {
                    self.i += 1;
                    let e = self.peek().ok_or("BAD_ESCAPE")?;
                    self.i += 1;
                    match e {
                        b'"' => s.push('"'),
                        b'\\' => s.push('\\'),
                        b'/' => s.push('/'),
                        b'b' => s.push('\u{8}'),
                        b'f' => s.push('\u{c}'),
                        b'n' => s.push('\n'),
                        b'r' => s.push('\r'),
                        b't' => s.push('\t'),
                        b'u' => {
                            let hi = self.hex4()?;
                            let code = if (0xD800..0xDC00).contains(&hi) {
                                if !self.b[self.i..].starts_with(b"\\u") {
                                    return Err("LONE_SURROGATE");
                                }
                                self.i += 2;
                                let lo = self.hex4()?;
                                if !(0xDC00..0xE000).contains(&lo) {
                                    return Err("LONE_SURROGATE");
                                }
                                0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00)
                            } else if (0xDC00..0xE000).contains(&hi) {
                                return Err("LONE_SURROGATE");
                            } else {
                                hi
                            };
                            s.push(char::from_u32(code).ok_or("BAD_ESCAPE")?);
                        }
                        _ => return Err("BAD_ESCAPE"),
                    }
                }
                Some(_) => return Err("CONTROL_BYTE"),
                None => return Err("UNTERMINATED"),
            }
        }
    }
    fn digits(&mut self) -> usize {
        let start = self.i;
        while self.peek().map_or(false, |c| c.is_ascii_digit()) {
            self.i += 1;
        }
        self.i - start
    }
    fn number(&mut self) -> Result<J, &'static str> {
        let start = self.i;
        if self.peek() == Some(b'-') {
            self.i += 1;
        }
        match self.peek() {
            Some(b'0') => self.i += 1,
            Some(b'1'..=b'9') => {
                self.digits();
            }
            _ => return Err("BAD_NUMBER"),
        }
        if self.peek() == Some(b'.') {
            self.i += 1;
            if self.digits() == 0 {
                return Err("BAD_NUMBER");
            }
        }
        if matches!(self.peek(), Some(b'e' | b'E')) {
            self.i += 1;
            if matches!(self.peek(), Some(b'+' | b'-')) {
                self.i += 1;
            }
            if self.digits() == 0 {
                return Err("BAD_NUMBER");
            }
        }
        Ok(J::Num(self.t[start..self.i].to_string()))
    }
}
