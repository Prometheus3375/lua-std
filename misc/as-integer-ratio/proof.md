# Proof

Any positive double *x* is 2<sup>(`exponent` - 1023)</sup> * ((0 or 1) + `mantissa` / 2<sup>52</sup>)
except for NaN and infinities. Thus, any double is rational and can be represented as a continued
fraction of the form

<p style="color: dimgrey; font-family: 'Cambria Math',math; font-size: large">
q = a<sub>0</sub> + 1 / (a<sub>1</sub> + 1 / (a<sub>2</sub> + 1 / (... + 1 / a<sub>k</sub>)))
= [a<sub>0</sub>; a<sub>1</sub>, a<sub>2</sub>, ..., a<sub>k</sub>],
</p>

where *k* and *a<sub>0</sub>* are non-negative integers and
*a<sub>1</sub>*, ..., *a<sub>k</sub>* are positive integers.

Let

<p style="color: dimgrey; font-family: 'Cambria Math',math; font-size: large">
x = x<sub>0</sub> =
a<sub>0</sub> + 1 / (a<sub>1</sub> + 1 / (a<sub>2</sub> + 1 / (... + 1 / a<sub>k</sub>)));
<br>
x<sub>i</sub> = a<sub>i</sub> + 1 / (a<sub>i+1</sub> + 1 / (... + 1 / a<sub>k</sub>)),
</p>

then

<p style="color: dimgrey; font-family: 'Cambria Math',math; font-size: large">
a<sub>i</sub> = floor(x<sub>i</sub>);
<br>
x<sub>i+1</sub> = a<sub>i+1</sub> + 1 / (a<sub>i+2</sub> + 1 / (... + 1 / a<sub>k</sub>))
<br> &nbsp;&nbsp;&nbsp;
&rArr; x<sub>i</sub> = a<sub>i</sub> + 1 / x<sub>i+1</sub>
<br> &nbsp;&nbsp;&nbsp;
&rArr; x<sub>i+1</sub> = 1 / (x<sub>i</sub> - a<sub>i</sub>)
<br> &nbsp;&nbsp;&nbsp;
&rArr; x<sub>i</sub> = 1 / (x<sub>i-1</sub> - a<sub>i-1</sub>).
</p>

Let

<p style="color: dimgrey; font-family: 'Cambria Math',math; font-size: large">
y<sub>0</sub> = a<sub>0</sub> = [a<sub>0</sub>];
<br>
y<sub>1</sub> = a<sub>0</sub> + 1 / a<sub>1</sub> = [a<sub>0</sub>; a<sub>1</sub>];
<br>
y<sub>i</sub>
= a<sub>0</sub> + 1 / (a<sub>1</sub> + 1 / (a<sub>2</sub> + 1 / (... + 1 / a<sub>i</sub>)))
= [a<sub>0</sub>; a<sub>1</sub>, ..., a<sub>i</sub>];
<br>
n<sub>-1</sub> = 1;
n<sub>0</sub> = a<sub>0</sub>;
n<sub>i</sub> = a<sub>i</sub>n<sub>i-1</sub> + n<sub>i-2</sub>;
<br>
d<sub>-1</sub> = 0;
d<sub>0</sub> = 1;
d<sub>i</sub> = a<sub>i</sub>d<sub>i-1</sub> + d<sub>i-2</sub>,
</p>

then

<p style="color: dimgrey; font-family: 'Cambria Math',math; font-size: large">
y<sub>i</sub> = n<sub>i</sub> / d<sub>i</sub>; &nbsp;&nbsp; (1)
<br>
y<sub>k</sub> = x<sub>0</sub> = x
<br> &nbsp;&nbsp;&nbsp;
&rArr; x = n<sub>k</sub> / d<sub>k</sub>.
</p>

## Proof of (1)

<p style="color: dimgrey; font-family: 'Cambria Math',math; font-size: large">
y<sub>0</sub> = a<sub>0</sub> = a<sub>0</sub> / 1 = n<sub>0</sub> / d<sub>0</sub>.
</p>

(1) holds for *y<sub>0</sub>*.
Assume (1) holds for *y<sub>j</sub>*.
Then proving (1) for *j + 1* proves (1) for any *i > 0* by induction.

By definition
<p style="color: dimgrey; font-family: 'Cambria Math',math; font-size: large">
y<sub>j</sub>
= a<sub>0</sub> + 1 / (a<sub>1</sub> + 1 / (... + 1 / a<sub>j</sub>))
<br> &nbsp;&nbsp;&nbsp;
= [a<sub>0</sub>; a<sub>1</sub>, ..., a<sub>j-1</sub>, a<sub>j</sub>]
<br> &nbsp;&nbsp;&nbsp;
= n<sub>j</sub> / d<sub>j</sub>
<br> &nbsp;&nbsp;&nbsp;
= (a<sub>j</sub> * n<sub>j-1</sub> + n<sub>j-2</sub>) /
  (a<sub>j</sub> * d<sub>j-1</sub> + d<sub>j-2</sub>);
<br>
y<sub>j+1</sub>
= a<sub>0</sub> + 1 / (a<sub>1</sub> + 1 / (... + 1 / (a<sub>j</sub> + 1 / a<sub>j+1</sub>))).
</p>

Therefore,

<p style="color: dimgrey; font-family: 'Cambria Math',math; font-size: large">
y<sub>j+1</sub>
= [a<sub>0</sub>; a<sub>1</sub>, ..., a<sub>j-1</sub>, a<sub>j</sub> + 1 / a<sub>j+1</sub>]
<br> &nbsp;&nbsp;&nbsp;
= ((a<sub>j</sub> + 1 / a<sub>j+1</sub>) * n<sub>j-1</sub> + n<sub>j-2</sub>) /
  ((a<sub>j</sub> + 1 / a<sub>j+1</sub>) * d<sub>j-1</sub> + d<sub>j-2</sub>)
<br> &nbsp;&nbsp;&nbsp;
= ((a<sub>j</sub>a<sub>j+1</sub> + 1) * n<sub>j-1</sub> + n<sub>j-2</sub>a<sub>j+1</sub>) /
  ((a<sub>j</sub>a<sub>j+1</sub> + 1) * d<sub>j-1</sub> + d<sub>j-2</sub>a<sub>j+1</sub>)
<br> &nbsp;&nbsp;&nbsp;
= (a<sub>j</sub>a<sub>j+1</sub>n<sub>j-1</sub> + n<sub>j-1</sub> + n<sub>j-2</sub>a<sub>j+1</sub>) /
  (a<sub>j</sub>a<sub>j+1</sub>d<sub>j-1</sub> + d<sub>j-1</sub> + d<sub>j-2</sub>a<sub>j+1</sub>)
<br> &nbsp;&nbsp;&nbsp;
= (a<sub>j+1</sub>(a<sub>j</sub>n<sub>j-1</sub> + n<sub>j-2</sub>) + n<sub>j-1</sub>) /
  (a<sub>j+1</sub>(a<sub>j</sub>d<sub>j-1</sub> + d<sub>j-2</sub>) + d<sub>j-1</sub>)
<br> &nbsp;&nbsp;&nbsp;
= (a<sub>j+1</sub>n<sub>j</sub> + n<sub>j-1</sub>) /
  (a<sub>j+1</sub>d<sub>j</sub> + d<sub>j-1</sub>)
<br> &nbsp;&nbsp;&nbsp;
= n<sub>j+1</sub> / d<sub>j+1</sub>.
</p>

# Sources

- [Double precision format - Wikipedia](https://en.wikipedia.org/wiki/Double-precision_floating-point_format)
- [Continued fraction - Wikipedia](https://en.wikipedia.org/wiki/Continued_fraction)
- [ContinuedFractions.pdf](https://pi.math.cornell.edu/~gautam/ContinuedFractions.pdf) (stored in
  this repo)
