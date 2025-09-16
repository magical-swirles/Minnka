import sys
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

short = True

default_output_path = "/tmp/visualize_matrix.csv"
online_overlay_path = "/tmp/visualize_matrix_online_overlay.csv"

def get_ticks(total_length, n_ticks):
    n_ticks = n_ticks - 1
    to_return = [1]
    for i in range(1, n_ticks):
        to_return.append(round((total_length - 1) / n_ticks) * i)
    to_return.append(total_length - 1)
    return to_return

def convert_to_processed_matrix(raw_matrix_file, short, reduced, output_path):
    lines = {}
    unique_traces = []
    tests = []
    with open(raw_matrix_file, 'r') as f:
        for line in f:
            stripped_line = line.strip()
            tests.append(stripped_line.split(',')[0])
            unique_traces += stripped_line.split(',')[1:]
            lines[stripped_line.split(',')[0]] = stripped_line.split(',')[1:]
    with open(output_path, "w", encoding="utf-8") as out:
        # Write header row
        header = []
        for i, trace in enumerate(unique_traces):
            header.append(f"\u03C4{i+1}" if short else trace.strip())
        out.write("," + ",".join(header))
        out.write("\n")
        # Write each test row
        for i, test in enumerate(tests):
            symbol = "O" if test in reduced else "X"
            # print(test, symbol)
            row = []
            row.append(f"t{i+1}" if short else test.strip())
            for trace in unique_traces:
                if trace in lines[test]:
                    row.append(symbol)
                else:
                    row.append("")
            out.write(",".join(row))
            out.write("\n")

def plot(output_path, output, clustering, stack_online):
    # Read the processed matrix
    df = pd.read_csv(output_path, index_col=0)

    # Convert 'X' to 1, empty to 0, and handle any NaN values
    # Convert to binary matrix

    # if stack_online is not None:
    #     df_online = pd.read_csv(online_overlay_path, index_col=0)
    #     heatmap_data = df.replace("X", 1).replace("", 0).replace("O", 1).fillna(0).astype(int)
    #     # For each cell in heatmap_data, if the corresponding cell in df_online has an "X", set value to -1
    #     for row in heatmap_data.index:
    #         for col in heatmap_data.columns:
    #             if row in df_online.index and col in df_online.columns:
    #                 if df_online.at[row, col] == "O":
    #                     heatmap_data.at[row, col] = -1
    # else:
    #     heatmap_data = df.replace("X", 1).replace("", 0).replace("O", -1).fillna(0).astype(int)
    heatmap_data = df.replace("X", 1).replace("", 0).replace("O", -1).fillna(0).astype(int)

    if clustering == "true":
        from scipy.cluster.hierarchy import linkage, leaves_list, optimal_leaf_ordering
        from scipy.spatial.distance import pdist, squareform

        # Perform hierarchical clustering on both axes using absolute values
        abs_heatmap = np.abs(heatmap_data.values)

        # Compute pairwise distances for rows and columns on absolute value
        row_dist = pdist(abs_heatmap, metric='euclidean')
        col_dist = pdist(abs_heatmap.T, metric='euclidean')

        # Linkage for rows and columns
        row_linkage = linkage(row_dist, method='average') if heatmap_data.shape[0] > 1 else None
        col_linkage = linkage(col_dist, method='average') if heatmap_data.shape[1] > 1 else None

        # Try to align clusters diagonally by using optimal leaf ordering
        if row_linkage is not None and col_linkage is not None:
            # Use optimal leaf ordering to align similar clusters
            # For diagonal, try to use the same order for rows and columns if possible
            # We'll use the row linkage to order both rows and columns if the matrix is square
            if heatmap_data.shape[0] == heatmap_data.shape[1]:
                # Use row linkage for both
                opt_row_linkage = optimal_leaf_ordering(row_linkage, squareform(row_dist))
                row_order = leaves_list(opt_row_linkage)
                col_order = row_order
            else:
                # Use optimal leaf ordering separately
                opt_row_linkage = optimal_leaf_ordering(row_linkage, squareform(row_dist))
                opt_col_linkage = optimal_leaf_ordering(col_linkage, squareform(col_dist))
                row_order = leaves_list(opt_row_linkage)
                col_order = leaves_list(opt_col_linkage)
        else:
            row_order = np.arange(heatmap_data.shape[0])
            col_order = np.arange(heatmap_data.shape[1])

        # Reorder the DataFrame
        heatmap_data = heatmap_data.iloc[row_order, :].iloc[:, col_order]
    # Add empty row as first row and empty column as first column
    # Create empty row with same number of columns
    empty_row = pd.Series([0] * heatmap_data.shape[1], index=heatmap_data.columns)
    # Create empty column with same number of rows  
    empty_col = pd.Series([0] * heatmap_data.shape[0], index=heatmap_data.index)
    
    # Add empty row at the beginning (This is for making the matrix start from 1)
    heatmap_data = pd.concat([empty_row.to_frame().T, heatmap_data], ignore_index=True)
    # Add empty column at the beginning
    heatmap_data = pd.concat([pd.DataFrame([0] * heatmap_data.shape[0], columns=['empty']), heatmap_data], axis=1)
    # Create a figure with minimal size - each cell will be roughly 1 pixel
    # Dynamically set figure size for square cells, max dimension 12
    # n_rows, n_cols = heatmap_data.shape
    # max_dim = max(n_rows, n_cols)
    # scale = 12 / max_dim if max_dim > 0 else 1
    # fig_width = n_cols * scale
    # fig_height = n_rows * scale
    # plt.figure(figsize=(fig_width, fig_height))
    # plt.figure(figsize=(12, 2)) # Offline
    plt.figure(figsize=(3.5, 1.4)) # Online

    from matplotlib.colors import ListedColormap, BoundaryNorm

    # Define a custom colormap: -1 (red), 0 (white), 1 (blue)
    cmap = ListedColormap(['red', 'white', 'blue'])
    bounds = [-1.5, -0.5, 0.5, 1.5]
    norm = BoundaryNorm(bounds, cmap.N)

    # Set the aspect ratio of the main plot (heatmap) instead of the whole figure
    plt.imshow(heatmap_data, cmap=cmap, norm=norm, aspect=4, interpolation='nearest')
    # plt.imshow(heatmap_data, cmap=cmap, norm=norm, aspect="auto", interpolation='nearest')

    # plt.colorbar(label="Visualization of Test-Trace Matrix")
    
    if short:
        n_ticks = min(16, len(heatmap_data.columns))
        if len(heatmap_data.columns) > n_ticks:
            step = len(heatmap_data.columns) // n_ticks
            x_ticks = np.arange(1, len(heatmap_data.columns), step)
            x_labels = [f"\u03C4{i+1}" for i in x_ticks]
        else:
            x_ticks = np.arange(len(heatmap_data.columns))
            x_labels = [f"\u03C4{i+1}" for i in x_ticks]

        n_y_ticks = min(4, len(heatmap_data.index))
        if len(heatmap_data.index) > n_y_ticks:
            step = len(heatmap_data.index) // n_y_ticks
            y_ticks = np.arange(1, len(heatmap_data.index), step)
            y_labels = [f"t{i+1}" for i in y_ticks]
        else:
            y_ticks = np.arange(len(heatmap_data.index))
            y_labels = [f"t{i+1}" for i in y_ticks]
    else:
        # Only show every nth tick to avoid overcrowding
        n_ticks = min(20, len(heatmap_data.columns))
        if len(heatmap_data.columns) > n_ticks:
            step = len(heatmap_data.columns) // n_ticks
            x_ticks = np.arange(1, len(heatmap_data.columns), step)
            x_labels = [heatmap_data.columns[i] for i in x_ticks]
        else:
            x_ticks = np.arange(len(heatmap_data.columns))
            x_labels = heatmap_data.columns

        n_y_ticks = min(20, len(heatmap_data.index))
        if len(heatmap_data.index) > n_y_ticks:
            step = len(heatmap_data.index) // n_y_ticks
            y_ticks = np.arange(1, len(heatmap_data.index), step)
            y_labels = [heatmap_data.index[i] for i in y_ticks]
        else:
            y_ticks = np.arange(len(heatmap_data.index))
            y_labels = heatmap_data.index
    
    # plt.xticks(ticks=x_ticks, labels=x_labels, rotation=90, fontsize=8)
    # plt.yticks(ticks=y_ticks, labels=y_labels, fontsize=8)
    # Set axis limits to show exact boundaries
    plt.xlim(0.5, len(heatmap_data.columns) - 0.5)
    plt.ylim(0.5, len(heatmap_data.index) - 0.5)
    
    # Set ticks to show begin and end of each axis
    # plt.xticks(get_ticks(len(heatmap_data.columns), 7))
    plt.xticks(get_ticks(len(heatmap_data.columns), 4))
    # plt.yticks(get_ticks(len(heatmap_data.index), 5))
    plt.yticks(get_ticks(len(heatmap_data.index), 3))

    plt.xlabel("Unique Traces")
    plt.ylabel("Tests")
    plt.tight_layout()
    if output is None:
        plt.show()
    else:
        plt.savefig(output, dpi=200)

if __name__ == "__main__":
    raw_matrix_file = sys.argv[1]
    output = sys.argv[2] if len(sys.argv) > 2 else None
    clustering = sys.argv[3] if len(sys.argv) > 3 else None
    reduced_file = sys.argv[4] if len(sys.argv) > 4 else None
    stack_online = sys.argv[5] if len(sys.argv) > 5 else None
    reduced = [line.strip() for line in open(reduced_file, "r").readlines()] if reduced_file else []
    convert_to_processed_matrix(raw_matrix_file, short, reduced, default_output_path)
    if stack_online is not None:
        convert_to_processed_matrix(raw_matrix_file, short, reduced, online_overlay_path)
    plot(default_output_path, output, clustering, stack_online)
