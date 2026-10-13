"""
H-1B Sponsor Explorer - Python visual: worksite tile map (Employer Profile page)

Paste this into a Power BI Python visual with these fields:
  - LCA[worksite_state]
  - [Certified LCAs CY]
Power BI passes them in as the `dataset` DataFrame.
Tiles are shaded on a log scale (dark = fewer LCAs, light = more); Texas is outlined in teal.
Requires: pandas, matplotlib
"""
import math
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

G = {"AK":(0,0),"ME":(10,0),"VT":(9,1),"NH":(10,1),
     "WA":(0,2),"ID":(1,2),"MT":(2,2),"ND":(3,2),"MN":(4,2),"WI":(5,2),"MI":(6,2),"NY":(8,2),"MA":(9,2),
     "OR":(0,3),"NV":(1,3),"WY":(2,3),"SD":(3,3),"IA":(4,3),"IL":(5,3),"IN":(6,3),"OH":(7,3),"PA":(8,3),"NJ":(9,3),"CT":(10,3),"RI":(11,3),
     "CA":(0,4),"UT":(1,4),"CO":(2,4),"NE":(3,4),"MO":(4,4),"KY":(5,4),"WV":(6,4),"VA":(7,4),"MD":(8,4),"DE":(9,4),
     "AZ":(1,5),"NM":(2,5),"KS":(3,5),"AR":(4,5),"TN":(5,5),"NC":(6,5),"SC":(7,5),"DC":(8,5),
     "OK":(3,6),"LA":(4,6),"MS":(5,6),"AL":(6,6),"GA":(7,6),
     "HI":(0,7),"TX":(3,7),"FL":(8,7)}

df = dataset.dropna()
v = {str(s).strip().upper(): float(n) for s, n in zip(df.iloc[:, 0], df.iloc[:, 1])}
mx = math.log10(max(v.values()) + 1) if v else 1

def shade(t):
    a = [(0x3A,0x1E,0x0C), (0xD9,0x62,0x0F), (0xFF,0xC9,0x8A)]
    i = 0 if t < 0.5 else 1
    u = t * 2 if t < 0.5 else (t - 0.5) * 2
    return tuple((a[i][k] + (a[i+1][k] - a[i][k]) * u) / 255 for k in range(3))

fig = plt.gcf()
fig.patch.set_facecolor("#151518")
ax = fig.add_axes([0, 0, 1, 1])
ax.set_facecolor("#151518")
ax.set_xlim(-0.1, 12.0)
ax.set_ylim(8.0, -0.1)
ax.set_aspect("equal")
ax.axis("off")

for st, (c, r) in G.items():
    n = v.get(st, 0)
    if n > 0:
        t = min(1, math.log10(n + 1) / mx)
        fc = shade(t)
        tc = "#1A0E06" if t > 0.6 else "#F6F2EC"
    else:
        fc = "#2A2A30"
        tc = "#8A837C"
    ax.add_patch(Rectangle((c, r), 0.88, 0.88, facecolor=fc,
                           edgecolor="#2DD4BF" if st == "TX" else "none", linewidth=2))
    ax.text(c + 0.44, r + 0.47, st, ha="center", va="center",
            fontsize=10, fontweight="bold", color=tc)

plt.show()
