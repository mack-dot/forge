// Slice 3: UNTRUSTED optimizer v2 (the fast one). No authority. Not proved. Outside the proved parts:
// the checker core judges every answer of this program.
// Safe Rust only: the standard library, no crate, no Cargo. Build (not pinned, not part of any proof):
//   rustc -D unsafe_code -D warnings --edition 2021 -C opt-level=2 -o <output> guests/booking/v2_fast.rs
// It reads ONE line (the problem as JSON) and writes ONE line (allocation, prices, stated gap).
//
// Method.
// 1. Batches in which every slot has the capacity 1 and every request needs one unbroken run of slots:
//    a dynamic program over the slots gives an optimum in one pass. With f(t) = the best value that the
//    slots before t can give, the price of slot t is f(t+1) - f(t). These prices are a certificate with
//    the gap 0.
// 2. Every other batch: the better of two greedy allocations, and the cheaper of two simple price
//    vectors. The stated gap is the smallest gap that these prices support.
#![forbid(unsafe_code)]

use std::io::{self, Read, Write};

struct Reader<'a> {
    bytes: &'a [u8],
    at: usize,
}

impl<'a> Reader<'a> {
    fn peek(&mut self) -> Option<u8> {
        while self.at < self.bytes.len() && self.bytes[self.at].is_ascii_whitespace() {
            self.at += 1;
        }
        self.bytes.get(self.at).copied()
    }
    fn eat(&mut self, wanted: u8) -> Option<()> {
        if self.peek()? == wanted {
            self.at += 1;
            Some(())
        } else {
            None
        }
    }
    fn text(&mut self) -> Option<String> {
        self.eat(b'"')?;
        let start = self.at;
        while self.at < self.bytes.len() && self.bytes[self.at] != b'"' {
            if self.bytes[self.at] == b'\\' {
                return None;
            }
            self.at += 1;
        }
        let found = std::str::from_utf8(&self.bytes[start..self.at]).ok()?.to_string();
        self.eat(b'"')?;
        Some(found)
    }
    fn list<T>(&mut self, item: fn(&mut Reader<'a>) -> Option<T>) -> Option<Vec<T>> {
        self.eat(b'[')?;
        let mut found = Vec::new();
        if self.peek()? == b']' {
            self.at += 1;
            return Some(found);
        }
        loop {
            found.push(item(self)?);
            match self.peek()? {
                b',' => self.at += 1,
                b']' => {
                    self.at += 1;
                    return Some(found);
                }
                _ => return None,
            }
        }
    }
    fn number(&mut self) -> Option<i128> {
        self.text()?.parse::<i128>().ok()
    }
    fn numbers(&mut self) -> Option<Vec<i128>> {
        self.list(Reader::number)
    }
}

struct Problem {
    capacity: Vec<i128>,
    needs: Vec<Vec<i128>>,
    values: Vec<i128>,
}

fn read_problem(line: &str) -> Option<Problem> {
    let mut reader = Reader { bytes: line.as_bytes(), at: 0 };
    let (mut capacity, mut needs, mut values) = (None, None, None);
    reader.eat(b'{')?;
    loop {
        let key = reader.text()?;
        reader.eat(b':')?;
        match key.as_str() {
            "capacity" => capacity = Some(reader.numbers()?),
            "needs" => needs = Some(reader.list(Reader::numbers)?),
            "values" => values = Some(reader.numbers()?),
            _ => return None,
        }
        match reader.peek()? {
            b',' => reader.at += 1,
            b'}' => break,
            _ => return None,
        }
    }
    let problem = Problem { capacity: capacity?, needs: needs?, values: values? };
    let (slots, requests) = (problem.capacity.len(), problem.values.len());
    if problem.needs.len() != slots || problem.needs.iter().any(|row| row.len() != requests) {
        return None;
    }
    Some(problem)
}

struct Answer {
    allocation: Vec<i128>,
    slot_prices: Vec<i128>,
    request_prices: Vec<i128>,
    alpha_bps: i128,
}

// The run of slots that request j needs, when the batch has the shape of method 1.
// None: the request needs no slot. Err: the batch does not have that shape.
fn run_of(problem: &Problem, j: usize) -> Result<Option<(usize, usize)>, ()> {
    let mut run: Option<(usize, usize)> = None;
    for (i, row) in problem.needs.iter().enumerate() {
        match row[j] {
            0 => {}
            1 => {
                run = match run {
                    None => Some((i, i)),
                    Some((first, last)) if last + 1 == i => Some((first, i)),
                    Some(_) => return Err(()),
                }
            }
            _ => return Err(()),
        }
    }
    Ok(run)
}

fn unit_runs(problem: &Problem) -> Option<Answer> {
    let (slots, requests) = (problem.capacity.len(), problem.values.len());
    if problem.capacity.iter().any(|&c| c != 1) {
        return None;
    }
    let mut runs = Vec::with_capacity(requests);
    for j in 0..requests {
        runs.push(run_of(problem, j).ok()?);
    }
    // best[t]: the best value that the slots before t can give. taken[t]: the request whose run ends
    // at slot t - 1 and gives best[t], if the best value needs one.
    let mut best = vec![0i128; slots + 1];
    let mut taken: Vec<Option<usize>> = vec![None; slots + 1];
    for t in 0..slots {
        best[t + 1] = best[t];
        for j in 0..requests {
            if let Some((first, last)) = runs[j] {
                if last == t && problem.values[j] > 0 && best[first] + problem.values[j] > best[t + 1] {
                    best[t + 1] = best[first] + problem.values[j];
                    taken[t + 1] = Some(j);
                }
            }
        }
    }
    let mut allocation = vec![0i128; requests];
    let mut request_prices = vec![0i128; requests];
    let mut t = slots;
    while t > 0 {
        match taken[t] {
            Some(j) => {
                allocation[j] = 1;
                t = runs[j].map(|(first, _)| first).unwrap_or(t - 1);
            }
            None => t -= 1,
        }
    }
    for j in 0..requests {
        if runs[j].is_none() && problem.values[j] > 0 {
            allocation[j] = 1;
            request_prices[j] = problem.values[j];
        }
    }
    let slot_prices = (0..slots).map(|t| best[t + 1] - best[t]).collect();
    Some(Answer { allocation, slot_prices, request_prices, alpha_bps: 0 })
}

fn greedy(problem: &Problem, order: &[usize]) -> Vec<i128> {
    let mut allocation = vec![0i128; problem.values.len()];
    let mut load = vec![0i128; problem.capacity.len()];
    for &j in order {
        let fits = problem.values[j] > 0
            && problem.needs.iter().enumerate().all(|(i, row)| load[i] + row[j] <= problem.capacity[i]);
        if fits {
            allocation[j] = 1;
            for (i, row) in problem.needs.iter().enumerate() {
                load[i] += row[j];
            }
        }
    }
    allocation
}

fn dot(a: &[i128], b: &[i128]) -> i128 {
    a.iter().zip(b).map(|(x, y)| x * y).sum()
}

fn general(problem: &Problem) -> Answer {
    let (slots, requests) = (problem.capacity.len(), problem.values.len());
    let span = |j: usize| -> i128 { problem.needs.iter().map(|row| row[j].max(0)).sum::<i128>() + 1 };
    let mut by_value: Vec<usize> = (0..requests).collect();
    by_value.sort_by(|&a, &b| problem.values[b].cmp(&problem.values[a]).then(a.cmp(&b)));
    let mut by_density: Vec<usize> = (0..requests).collect();
    by_density.sort_by(|&a, &b| (problem.values[b] * span(a)).cmp(&(problem.values[a] * span(b))).then(a.cmp(&b)));
    let (first, second) = (greedy(problem, &by_value), greedy(problem, &by_density));
    let allocation = if dot(&second, &problem.values) > dot(&first, &problem.values) { second } else { first };
    let value = dot(&allocation, &problem.values);

    // Prices 1: no slot price; every request pays its own value.
    let mut slot_prices = vec![0i128; slots];
    let mut request_prices: Vec<i128> = problem.values.iter().map(|&v| v.max(0)).collect();
    let mut bound: i128 = request_prices.iter().sum();
    // Prices 2 (only when no need and no capacity is negative): each request with a value is paid for
    // by the slot of least capacity among the slots that it needs.
    let plain = problem.capacity.iter().all(|&c| c >= 0) && problem.needs.iter().all(|row| row.iter().all(|&a| a >= 0));
    if plain {
        let mut by_slot = vec![0i128; slots];
        let mut by_request = vec![0i128; requests];
        for j in 0..requests {
            if problem.values[j] <= 0 {
                continue;
            }
            let payer = (0..slots).filter(|&i| problem.needs[i][j] >= 1).min_by_key(|&i| (problem.capacity[i], i));
            match payer {
                Some(i) => {
                    let need = problem.needs[i][j];
                    by_slot[i] = by_slot[i].max((problem.values[j] + need - 1) / need);
                }
                None => by_request[j] = problem.values[j],
            }
        }
        let other = dot(&by_slot, &problem.capacity) + by_request.iter().sum::<i128>();
        if other < bound {
            slot_prices = by_slot;
            request_prices = by_request;
            bound = other;
        }
    }
    // The smallest gap (basis points) with (10000 - gap) * bound <= 10000 * value.
    let alpha_bps = if bound <= value || bound <= 0 {
        0
    } else {
        ((10000 * (bound - value) + bound - 1) / bound).min(10000)
    };
    Answer { allocation, slot_prices, request_prices, alpha_bps }
}

fn texts(values: &[i128]) -> String {
    let quoted: Vec<String> = values.iter().map(|v| format!("\"{}\"", v)).collect();
    format!("[{}]", quoted.join(","))
}

fn main() {
    let mut input = String::new();
    if io::stdin().read_to_string(&mut input).is_err() {
        std::process::exit(2);
    }
    let line = input.lines().next().unwrap_or("");
    let problem = match read_problem(line) {
        Some(problem) => problem,
        None => std::process::exit(2),
    };
    let answer = unit_runs(&problem).unwrap_or_else(|| general(&problem));
    let out = format!(
        "{{\"allocation\":{},\"alphaBps\":\"{}\",\"requestPrices\":{},\"slotPrices\":{}}}\n",
        texts(&answer.allocation),
        answer.alpha_bps,
        texts(&answer.request_prices),
        texts(&answer.slot_prices)
    );
    if io::stdout().write_all(out.as_bytes()).is_err() {
        std::process::exit(2);
    }
}
