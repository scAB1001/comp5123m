import matplotlib.pyplot as plt
import seaborn as sns


class PerformanceDashboard:
    """Generates professional, industry-standard comparative NFV performance graphs."""

    def __init__(self):
        # 1. Base Configuration & Data
        self.environments = [
            'Cloud Node\n(Minikube / Docker)', 'Edge Node\n(K3s / containerd)']
        self.colors = ['#2B5B84', '#E15759']

        # 2. Metric Dictionary
        self.metrics = {
            'tcp_throughput': {
                'data': [1.36, 1.47],
                'title': 'Layer 4 TCP Throughput',
                'ylabel': 'Bandwidth (Gbps)',
                'ylim': 1.7,
                'format': '{:.2f} Gbps'
            },
            'http_reqs': {
                'data': [1029.30, 1053.75],
                'title': 'Layer 7 Application Processing Load',
                'ylabel': 'Requests / Second',
                'ylim': 1250,
                'format': '{:.1f} Req/s'
            },
            'http_lat': {
                'data': [96.34, 94.14],
                'title': 'Layer 7 Application Latency',
                'ylabel': 'Latency (ms)',
                'ylim': 135,
                'format': '{:.2f} ms'
            },
            'ping_lat': {
                'data': [0.085, 0.110],
                'title': 'Baseline ICMP Network Latency',
                'ylabel': 'Latency (ms)',
                'ylim': 0.13,
                'format': '{:.3f} ms'
            }
        }

        self._setup_theme()

    def _setup_theme(self):
        """Applies global seaborn theme settings."""
        sns.set_theme(style="whitegrid", palette="muted")

    def _annotate_bars(self, ax, data, format_str):
        """Adds floating text labels above each bar."""
        for p, val in zip(ax.patches, data):
            ax.annotate(format_str.format(val),
                        (p.get_x() + p.get_width() / 2., val),
                        ha='center', va='center',
                        xytext=(0, 10),
                        textcoords='offset points',
                        fontsize=12, fontweight='bold', color='#333333')

    def _plot_metric(self, ax, metric_info):
        """Handles the plotting logic for a single subplot."""
        sns.barplot(
            x=self.environments,
            y=metric_info['data'],
            ax=ax,
            hue=self.environments,
            palette=self.colors,
            legend=False
        )

        # Apply labels and scaling
        ax.set_title(metric_info['title'], fontsize=14,
                     fontweight='bold', pad=15)
        ax.set_ylabel(metric_info['ylabel'], fontsize=12, fontweight='bold')
        ax.set_ylim(0, metric_info['ylim'])

        # Call annotation helper
        self._annotate_bars(ax, metric_info['data'], metric_info['format'])

    def build_dashboard(self, filename='nfv_performance_analysis.png'):
        """Assembles the subplots, refines aesthetics, and exports the final image."""
        fig, axes = plt.subplots(2, 2, figsize=(14, 12))

        # Iterating flat axes against metrics dict
        for ax, metric_key in zip(axes.flat, self.metrics.keys()):
            self._plot_metric(ax, self.metrics[metric_key])

        # Refine global aesthetics
        for ax in axes.flat:
            ax.tick_params(axis='x', labelsize=12)
            ax.tick_params(axis='y', labelsize=11)
            sns.despine(ax=ax, left=True)

        # Apply Main Title
        fig.suptitle('5G Service Function Chain (SFC) Performance Analysis:\nCloud vs. Edge Orchestration',
                     fontsize=18, fontweight='bold', y=1.02, color='#111111')

        # Adjust layout and render
        plt.tight_layout()
        plt.savefig(filename, dpi=300, bbox_inches='tight')
        print(f"Graph saved as '{filename}'")


if __name__ == "__main__":
    dashboard = PerformanceDashboard()
    dashboard.build_dashboard()
