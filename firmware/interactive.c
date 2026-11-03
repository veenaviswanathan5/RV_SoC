#include <stdint.h>

#define WIDTH  320
#define HEIGHT 240
#define SIZE   20

#define KEYS (*(volatile uint32_t *)0x30000004u)
#define TIMER_MS (*(volatile uint32_t *)0x3000000Cu)

static volatile uint32_t *const framebuffer =
    (volatile uint32_t *)0x20000000u;

static void square(int x, int y, uint32_t colour)
{
    for (int row = 0; row < SIZE; ++row)
        for (int col = 0; col < SIZE; ++col)
            framebuffer[(y + row) * WIDTH + x + col] = colour;
}

int main(void)
{
    const uint32_t background = 0xff101820u;
    int x = 150;
    int y = 110;
    uint32_t previous_keys = 0;
    uint32_t previous_colour_keys = 0;
    uint32_t last_update = TIMER_MS;

    for (int i = 0; i < WIDTH * HEIGHT; ++i)
        framebuffer[i] = background;

    square(x, y, 0xff00ff00u);

    for (;;) {
        uint32_t keys = KEYS;
        uint32_t pressed = keys & ~previous_keys;
        previous_keys = keys;

        if (keys & 32u)
            return 0; /* Escape */

        uint32_t now = TIMER_MS;

        /* Only update game state every 16 milliseconds */
        if ((uint32_t)(now - last_update) >= 16u) {
            last_update = now;

            int next_x = x;
            int next_y = y;

            /* Now using 'keys' instead of 'pressed' for continuous movement */
            if (keys & 1u) next_x -= 5; /* Left */
            if (keys & 2u) next_x += 5; /* Right */
            if (keys & 4u) next_y -= 5; /* Up */
            if (keys & 8u) next_y += 5; /* Down */

            if (next_x < 0) next_x = 0;
            if (next_y < 0) next_y = 0;
            if (next_x > WIDTH - SIZE) next_x = WIDTH - SIZE;
            if (next_y > HEIGHT - SIZE) next_y = HEIGHT - SIZE;

            if (next_x != x || next_y != y ||
                ((keys ^ previous_colour_keys) & 16u)) {
                square(x, y, background);
                x = next_x;
                y = next_y;
                square(x, y, (keys & 16u) ? 0xffffff00u : 0xff00ff00u);
            }

            previous_colour_keys = keys;
        }
    }
}
