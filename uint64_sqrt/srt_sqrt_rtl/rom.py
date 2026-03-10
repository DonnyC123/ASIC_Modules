import math

import math

print("always_comb begin")
for i in range(256 // 4):
    if i < 64 // 4:
        print(f"  q_seed_rom[{i}] = 8'd0;")
    else:
        x_mid = (i + 0.5) / 64.0
        root = math.sqrt(x_mid)

        seed = round(root * 64.0)

        if seed > 63:
            seed = 63

        print(f"  q_seed_rom[{i}] = 8'd{seed};")
