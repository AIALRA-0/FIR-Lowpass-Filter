import argparse
import json

import numpy as np
from scipy import signal


def db_to_dev(ap_db: float, ast_db: float):
    dp = (10 ** (ap_db / 20.0) - 1.0) / (10 ** (ap_db / 20.0) + 1.0)
    ds = 10 ** (-ast_db / 20.0)
    return dp, ds


def design_filter(args):
    numtaps = args.order + 1
    wp = args.wp
    ws = args.ws
    cutoff = 0.5 * (wp + ws)

    if args.method == "firpm":
        coeffs = signal.remez(
            numtaps,
            [0.0, wp, ws, 1.0],
            [1.0, 0.0],
            weight=[1.0, args.stop_weight],
            fs=2.0,
            maxiter=100,
        )
    elif args.method == "firls":
        coeffs = signal.firls(
            numtaps,
            [0.0, wp, ws, 1.0],
            [1.0, 1.0, 0.0, 0.0],
            weight=[1.0, args.stop_weight],
            fs=2.0,
        )
    elif args.method == "kaiser":
        width = max(ws - wp, 1e-6)
        _, beta = signal.kaiserord(args.ast_target, width)
        coeffs = signal.firwin(
            numtaps,
            cutoff,
            window=("kaiser", beta),
            fs=2.0,
        )
    else:
        raise ValueError(f"Unknown method: {args.method}")

    payload = {
        "method": args.method,
        "order": args.order,
        "numtaps": numtaps,
        "coeffs": [float(x) for x in np.asarray(coeffs).tolist()],
    }
    print(json.dumps(payload))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--method", required=True, choices=["firpm", "firls", "kaiser"])
    parser.add_argument("--order", required=True, type=int)
    parser.add_argument("--wp", required=True, type=float)
    parser.add_argument("--ws", required=True, type=float)
    parser.add_argument("--stop-weight", required=True, type=float)
    parser.add_argument("--ap-target", required=True, type=float)
    parser.add_argument("--ast-target", required=True, type=float)
    args = parser.parse_args()
    design_filter(args)


if __name__ == "__main__":
    main()

