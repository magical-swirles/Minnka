import numpy as np
import matplotlib.pyplot as plt
import sys

# Optionally allow color separation via command line argument
# Usage: python plot_correlation.py [--color-separation]
color_separation = False
if len(sys.argv) > 1 and sys.argv[1] == "--color-separation":
    color_separation = True

# Read data from data.tsv
x_vals = []
y_vals = []
names = []
flags = []
with open("data.tsv", "r") as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) < 3:
            continue
        # Accept both 3 or 4 columns, but always take the first three as name, x, y
        name, x, y = parts[:3]
        flag = None
        if color_separation and len(parts) >= 4:
            flag_str = parts[3].strip().lower()
            if flag_str in ("true", "1", "yes"):
                flag = True
            elif flag_str in ("false", "0", "no"):
                flag = False
            else:
                flag = None
        try:
            x = float(x)
            y = float(y)
        except ValueError:
            continue
        x_vals.append(x)
        y_vals.append(y)
        names.append(name)
        flags.append(flag if color_separation else None)

x_vals = np.array(x_vals)
y_vals = np.array(y_vals)
names = np.array(names)
flags = np.array(flags)

plt.figure(figsize=(7,5))

# Fit the overall trendline
fit = np.polyfit(x_vals, y_vals, 1)
fit_fn = np.poly1d(fit)

# Separate points above and below the trendline
y_pred = fit_fn(x_vals)
above_mask = y_vals > y_pred
below_mask = y_vals <= y_pred

# Write names above and below the line to files
with open("above.txt", "w") as f_above, open("below.txt", "w") as f_below:
    for i in range(len(names)):
        if above_mask[i]:
            f_above.write(f"{names[i]}\n")
        else:
            f_below.write(f"{names[i]}\n")

# Color by 4th column if present and color_separation is enabled, otherwise fallback to above/below trendline
if color_separation and np.any(flags != None):
    # True: green, False: red, None: gray
    true_mask = flags == True
    false_mask = flags == False
    none_mask = flags == None
    plt.scatter(x_vals[true_mask], y_vals[true_mask], c='green', alpha=0.7, label='Flag True')
    plt.scatter(x_vals[false_mask], y_vals[false_mask], c='red', alpha=0.7, label='Flag False')
    if np.any(none_mask):
        plt.scatter(x_vals[none_mask], y_vals[none_mask], c='gray', alpha=0.7, label='Flag Unknown')
else:
    # Plot the two groups with different colors (original behavior)
    plt.scatter(x_vals[above_mask], y_vals[above_mask], c='blue', alpha=0.7, label='Above trendline')
    plt.scatter(x_vals[below_mask], y_vals[below_mask], c='orange', alpha=0.7, label='Below trendline')

# Fit and plot trendline for above group (if enough points)
if np.sum(above_mask) > 1:
    fit_above = np.polyfit(x_vals[above_mask], y_vals[above_mask], 1)
    fit_fn_above = np.poly1d(fit_above)
    x_sorted_above = np.sort(x_vals[above_mask])
    plt.plot(x_sorted_above, fit_fn_above(x_sorted_above), color='blue', linestyle='--', label='Fit (above)')
    # R^2 for above group
    y_pred_above = fit_fn_above(x_vals[above_mask])
    ss_res_above = np.sum((y_vals[above_mask] - y_pred_above) ** 2)
    ss_tot_above = np.sum((y_vals[above_mask] - np.mean(y_vals[above_mask])) ** 2)
    r2_above = 1 - ss_res_above / ss_tot_above if ss_tot_above != 0 else float('nan')
else:
    fit_fn_above = None
    r2_above = float('nan')

# Fit and plot trendline for below group (if enough points)
if np.sum(below_mask) > 1:
    fit_below = np.polyfit(x_vals[below_mask], y_vals[below_mask], 1)
    fit_fn_below = np.poly1d(fit_below)
    x_sorted_below = np.sort(x_vals[below_mask])
    plt.plot(x_sorted_below, fit_fn_below(x_sorted_below), color='orange', linestyle='--', label='Fit (below)')
    # R^2 for below group
    y_pred_below = fit_fn_below(x_vals[below_mask])
    ss_res_below = np.sum((y_vals[below_mask] - y_pred_below) ** 2)
    ss_tot_below = np.sum((y_vals[below_mask] - np.mean(y_vals[below_mask])) ** 2)
    r2_below = 1 - ss_res_below / ss_tot_below if ss_tot_below != 0 else float('nan')
else:
    fit_fn_below = None
    r2_below = float('nan')

# Plot the overall trendline
x_sorted = np.sort(x_vals)
plt.plot(x_sorted, fit_fn(x_sorted), color='red', label='Overall linear fit')

# R^2 calculation for overall fit
ss_res = np.sum((y_vals - y_pred) ** 2)
ss_tot = np.sum((y_vals - np.mean(y_vals)) ** 2)
r2 = 1 - ss_res / ss_tot

plt.xlabel("X")
plt.ylabel("Y")
plt.title(
    f"Scatter plot with group trendlines\n"
    f"Overall R$^2$ = {r2:.3f}, "
    f"Above R$^2$ = {r2_above:.3f}, "
    f"Below R$^2$ = {r2_below:.3f}"
)
plt.legend()
plt.tight_layout()
plt.show()
