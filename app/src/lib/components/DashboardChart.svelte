<script lang="ts">
	import { onMount } from 'svelte';
	import {
		Chart,
		DoughnutController,
		ArcElement,
		Tooltip,
		Legend,
		type ChartType,
		type ChartData
	} from 'chart.js';

	Chart.register(DoughnutController, ArcElement, Tooltip, Legend);

	type Props = {
		type: ChartType;
		data: ChartData;
		options?: Record<string, unknown>;
	};

	let { type, data, options = {} }: Props = $props();

	let canvas: HTMLCanvasElement;
	let chart: Chart | null = null;

	onMount(() => {
		chart = new Chart(canvas, {
			type,
			data: $state.snapshot(data) as ChartData,
			options: options as never
		});

		return () => {
			chart?.destroy();
			chart = null;
		};
	});

	$effect(() => {
		if (!chart) return;
		chart.data = $state.snapshot(data) as ChartData;
		chart.update();
	});
</script>

<canvas bind:this={canvas}></canvas>
