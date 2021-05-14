#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# https://raw.githubusercontent.com/ptrktn/boffinlab/main/tools/dateforecast.py

import sys
import os
import getopt
import datetime
import itertools


def usage():
    print("Usage: %s [OPTIONS] INFILE OUTFILE" %
          os.path.basename(os.path.realpath(__file__)))
    print("Options are as follows:")
    print("   -h    show help")
    print("   -n    max number of forecast points")
    print("   -x    date column")
    print("   -x    metric column")
    print("INFILE format:")
    print("YYYY-MM-DD  METRIC")

    sys.exit(1)


# Ordinary Least Square (not to be confused with Oulun Luistinseura)
# Simple linear regression model y = a + b x
class OLS:
    def __init__(self):
        self.a = None
        self.b = None
        self.n = None
        self.x = None
        self.y = None
        self.coef_ = None
        self.intercept_ = None


    def fit(self, x, y):
        assert(len(x) > 0)
        rows = len(x)
        cols = len(x[0])
        assert(1 == cols)
        assert(rows == len(y))
        self.x = list(itertools.chain.from_iterable(x))
        self.y = y
        self.n = len(x)
        nsxy = self.n * sum([self.x[i]*self.y[i] for i in range(self.n)])
        sx = sum(self.x)
        sy = sum(self.y)
        nsx2 = self.n * sum([self.x[i]*self.x[i] for i in range(self.n)])
        self.b = (nsxy - sx*sy)/(nsx2 - sx*sx)
        self.a = (sy - self.b*sx)/self.n
        self.intercept_ = self.a
        self.coef_ = [self.b]


    def predict(self , x):
        return self.a + self.b*x


def date2e(s):
    return float(datetime.datetime.strptime(s, "%Y-%m-%d").timestamp())


def e2date(s):
    return datetime.datetime.fromtimestamp(s).strftime("%Y-%m-%d")


def main(argv):
    # The first column is date
    xcol = 0
    # The second column is metric
    ycol = 1
    ndates = 14

    try:
        opts, args = getopt.getopt(argv, "hn:x:y:")
    except getopt.GetoptError:
        usage()

    for opt, arg in opts:
        if '-h' == opt:
            usage()
        elif '-n' == opt:
            ndates = int(arg)
        elif '-x' == opt:
            xcol = max(0, int(arg) - 1)
        elif '-y' == opt:
            ycol = max(0, int(arg) - 1)
            

    argc = len(args)

    if 2 != argc:
        usage()

    ifname = args[0]
    ofname = args[1]
    x = []
    y = []

    with open(ifname) as fp:
        for line in fp.readlines():
            a = line.split()
            x.append([date2e(a[xcol])])
            y.append(float(a[ycol]))

    assert(len(x) > 0)

    reg = OLS()
    ols = reg.fit(x, y)
    k = reg.coef_[0]
    y0 = reg.intercept_
    print("y0 = %f k = %f" % (y0, k))

    if k < 0:
        z = -y0/k
        print("Estimated zero date: %s" % str(e2date(z)))
        ndates = 14

    with open(ofname, "w") as fp:
        x1 = x[-1][0]
        for d in range(ndates):
            x = x1 + (d + 1)*24*60*60
            y = round(reg.predict(x), 2)
            if y < 0:
                break
            fp.write("%s\t%f\n" % (str(e2date(x)), y))


if "__main__" == __name__:
    main(sys.argv[1:])
