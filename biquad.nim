
#
# Implementation of simple second order IIR biquad filters: low pass, high
# pass, band pass and band stop.
#

import math

type

  BiquadKind* = enum
    BiquadLowPass,
    BiquadHighPass,
    BiquadBandPass,
    BiquadBandStop,

  Biquad* = object
    kind: BiquadKind
    freq: float
    Q: float

    x1, x2: float
    y0, y1, y2: float
    b0_a0, b1_a0, b2_a0: float
    a1_a0, a2_a0: float
    first: bool


proc config*(bq: var Biquad, kind: BiquadKind, freq: float, Q: float) =

  if bq.kind == kind and bq.freq == freq and bq.Q == Q:
    return

  bq.kind = kind
  bq.freq = freq
  bq.Q = Q

  let
    f = freq
    alpha = sin(f) / (2.0 * Q)
    cos_w0 = cos(f)

  var
    a0, a1, a2, b0, b1, b2: float

  case kind

    of BiquadLowPass:
      b0 = (1.0 - cos_w0) / 2.0
      b1 = 1.0 - cos_w0
      b2 = (1.0 - cos_w0) / 2.0
      a0 = 1.0 + alpha
      a1 = -2.0 * cos_w0
      a2 = 1.0 - alpha

    of BiquadHighPass:
      b0 = (1.0 + cos_w0) / 2.0
      b1 = -(1.0 + cos_w0)
      b2 = (1.0 + cos_w0) / 2.0
      a0 = 1.0 + alpha
      a1 = -2.0 * cos_w0
      a2 = 1.0 - alpha

    of BiquadBandPass:
      b0 = Q * alpha
      b1 = 0.0
      b2 = -Q * alpha
      a0 = 1.0 + alpha
      a1 = -2.0 * cos_w0
      a2 = 1.0 - alpha

    of BiquadBandStop:
      b0 = 1.0
      b1 = -2.0 * cos_w0
      b2 = 1.0
      a0 = 1.0 + alpha
      a1 = -2.0 * cos_w0
      a2 = 1.0 - alpha

  let a0r = 1.0 / a0
  bq.b0_a0 = b0 * a0r
  bq.b1_a0 = b1 * a0r
  bq.b2_a0 = b2 * a0r
  bq.a1_a0 = a1 * a0r
  bq.a2_a0 = a2 * a0r


proc initBiquad*(kind=BiquadLowpass, freq=0.5, Q=0.707): Biquad =
  var bq: Biquad
  bq.first = true
  bq.config(kind, freq, Q)
  result = bq


proc run*(bq: var Biquad, v_in: float): float =
  let x0 = v_in

  if bq.first:
    bq.y1 = x0
    bq.y2 = x0
    bq.x1 = x0
    bq.x2 = x0;
    bq.first = false;

  let y0 =
    bq.b0_a0 * x0 +
    bq.b1_a0 * bq.x1 +
    bq.b2_a0 * bq.x2 -
    bq.a1_a0 * bq.y1 -
    bq.a2_a0 * bq.y2

  bq.x2 = bq.x1
  bq.x1 = x0
  bq.y2 = bq.y1
  bq.y1 = y0

  result = y0

