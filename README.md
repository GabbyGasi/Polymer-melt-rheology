# Polymer Melt Rheology: From Viscosity Data to Extrusion Design

*Work in progress*

## Overview

How easily a molten plastic flows decides how it can be processed: how hot it must be, how fast it can be extruded, and how much pressure the machine needs. This project analyzes published rheology data for two polypropylene (PP) melts in MATLAB to:

1. Quantify how temperature changes melt viscosity (time-temperature superposition and flow activation energy)
2. Fit standard viscosity models (power-law, Cross, Carreau) to a flow curve covering more than six orders of magnitude in shear rate
3. Use the fitted model to estimate the pressure needed to push the melt through an extrusion die

## Data

All data come from the NETZSCH application note *Polymers and Temperature – A Hot Relationship* (AN 297, Strasser & Gezgin, 2023):

| Sample | Source | Conditions | Used for |
|---|---|---|---|
| A | Figure 1 | Rotational rheometer (cone-plate), 190-230 °C, nitrogen | Temperature dependence |
| B | Figure 5 | Rotational + capillary rheometer, 190 °C | Viscosity model fitting |

Values were read from the published figures with WebPlotDigitizer (`data/raw/`) and converted to clean tables by `scripts/prepare_data.m` (`data/processed/`). For Sample A, only shear rates up to 4 s⁻¹ are used: above that, the melt is pushed out of the rheometer gap and the measured viscosity is not reliable.

## Results

### 1. Effect of temperature (Sample A)

![Effect of temperature on the melt viscosity of polypropylene](figures/temperature_dependence.png)

*(a) Measured viscosity at five temperatures. (b) Master curve: each curve shifted by its shift factor a_T onto the 190 °C reference. (c) Arrhenius plot of the shift factors.*

- Between 190 and 230 °C, the zero-shear viscosity falls from 1,684 to 511 Pa·s, so the melt becomes about 3.3 times more fluid.
- All five curves collapse onto one master curve, so time-temperature superposition holds for this polypropylene.
- Between 190 and 210 °C, the flow activation energy is 42 kJ/mol, close to the 40 ± 1 kJ/mol reported for polypropylene by Fambri et al. (2008).
- At 220 and 230 °C, the viscosity drops faster than the Arrhenius equation predicts, which raises the apparent activation energy to 57 kJ/mol. This is consistent with thermal degradation (chain scission) at high temperature, but the data alone cannot confirm it.

### 2. Viscosity model fitting (Sample B)

![Viscosity model fits for polypropylene at 190 °C](figures/model_fits.png)

*(a) Flow curve of Sample B at 190 °C from a rotational rheometer (orange) and a capillary rheometer (blue), with three fitted viscosity models. The shaded band marks typical extrusion shear rates (about 100-1000 s⁻¹). (b) Difference between each model and the data.*

| Model | η₀ (Pa·s) | λ (s) | n | K (Pa·sⁿ) | Typical error |
|---|---|---|---|---|---|
| Power law (≥ 50 s⁻¹ only) | - | - | 0.32 | 15,600 | 11% |
| Cross | 4,646 | 0.15 | 0.31 | - | 7% |
| Carreau | 4,170 | 0.27 | 0.38 | - | 16% |

- The viscosity falls by a factor of almost 400, from about 4,600 Pa·s on the plateau to about 12 Pa·s at 38,500 s⁻¹. This strong shear thinning is typical of polypropylene.
- The Cross model fits best over the whole range (typical error 7%). Its time constant λ ≈ 0.15 s means shear thinning starts at about 1/λ ≈ 7 s⁻¹: above this rate, the polymer chains no longer have time to relax and start to align with the flow.
- The Carreau model bends from the plateau into shear thinning too sharply for this polymer, with errors of up to about 28%.
- The power law describes the high-shear region well (n ≈ 0.32) but has no plateau, so it predicts unrealistically high viscosities at low shear rates.
- In the extrusion range, the Cross and power-law models predict viscosities 8-15% below the capillary data. One reason is that the rotational and capillary measurements differ by about 13% where they overlap (around 50 s⁻¹).

## Planned analysis
