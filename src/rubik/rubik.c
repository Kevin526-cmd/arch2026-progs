#include <stdint.h>

#include "rubik.h"
#include "tables.h"

static int heuristic(uint16_t P, uint16_t O, uint8_t ca, uint8_t cb)
{
    int a = ca & 3;
    int b = cb & 3;
    int index = (P << 3) + P + (a << 1) + a + b;
    int h_po = dist_po[index];
    int h_o = dist_o[O];
    return h_po > h_o ? h_po : h_o;
}

static uint16_t stP[16], stO[16];
static uint8_t stA[16], stB[16];
static uint8_t cur_face[16];
static uint8_t cur_turn[16];
static uint8_t path_face[16];
static uint8_t path_turn[16];

static int search_iter(uint16_t P,
                       uint16_t O,
                       uint8_t ca,
                       uint8_t cb,
                       int bound,
                       int *next_bound)
{
    int d = 0;
    int min_f = 99;
    stP[0] = P;
    stO[0] = O;
    stA[0] = ca;
    stB[0] = cb;
    cur_face[0] = 0;
    cur_turn[0] = 0;
    if (P == 0 && O == 0)
        return 0;

    while (d >= 0) {
        int face = cur_face[d];
        if (face == 3) {
            d--;
            continue;
        }
        int turn = cur_turn[d];
        if (turn == 0 && d > 0 && face == path_face[d - 1]) {
            cur_face[d] = (uint8_t) (face + 1);
            continue;
        }


        if (turn == 2) {
            cur_face[d] = (uint8_t) (face + 1);
            cur_turn[d] = 0;
        } else {
            cur_turn[d] = (uint8_t) (turn + 1);
        }

        if (turn == 0) {
            stP[d + 1] = permutation[face][stP[d]];
            stO[d + 1] = orientation[face][stO[d]];
            stA[d + 1] = cubie_move[face][stA[d]];
            stB[d + 1] = cubie_move[face][stB[d]];
        } else {
            stP[d + 1] = permutation[face][stP[d + 1]];
            stO[d + 1] = orientation[face][stO[d + 1]];
            stA[d + 1] = cubie_move[face][stA[d + 1]];
            stB[d + 1] = cubie_move[face][stB[d + 1]];
        }

        int f =
            d + 1 + heuristic(stP[d + 1], stO[d + 1], stA[d + 1], stB[d + 1]);
        if (f > bound) {
            if (f < min_f)
                min_f = f;
            continue;
        }
        path_face[d] = (uint8_t) face;
        path_turn[d] = (uint8_t) turn;
        if (stP[d + 1] == 0 && stO[d + 1] == 0)
            return d + 1;
        d++;
        cur_face[d] = 0;
        cur_turn[d] = 0;
    }
    *next_bound = min_f;
    return -1;
}

static int solve(uint16_t P, uint16_t O, uint8_t ca, uint8_t cb)
{
    int bound = heuristic(P, O, ca, cb);

    for (;;) {
        int next_bound;
        int n = search_iter(P, O, ca, cb, bound, &next_bound);
        if (n >= 0)
            return n;
        bound = next_bound;
    }
}

static int parse(const char *s,
                 uint16_t *P,
                 uint16_t *O,
                 uint8_t *ca,
                 uint8_t *cb)
{
    uint8_t p[7], o[7];
    unsigned seen = 0, osum = 0;

    for (int i = 0; i < RUBIK_STATE_LEN; ++i)
        if (s[i] == '\0')
            return -1;

    if (s[RUBIK_STATE_LEN] != '\0')
        return -1;

    for (int i = 0; i < 7; ++i) {
        unsigned c = (unsigned) (s[i] - '1');
        unsigned t = (unsigned) (s[i + 7] - '1');
        if (c > 6 || t > 2 || (seen & (1u << c)))
            return -1;
        seen |= (1u << c);
        osum += t;
        p[i] = (uint8_t) c;
        o[i] = (uint8_t) t;
        if (c == 0)
            *ca = (uint8_t) ((i << 2) + t);
        if (c == 1)
            *cb = (uint8_t) ((i << 2) + t);
    }

    while (osum >= 3)
        osum -= 3;
    if (osum != 0)
        return -1;

    uint16_t oo = 0;
    for (int i = 0; i < 6; ++i)
        oo = (uint16_t) ((oo << 1) + oo + o[i]);
    *O = oo;

    static const uint16_t weight[7] = {720, 120, 24, 6, 2, 1, 0};

    uint16_t pp = 0;
    for (int i = 0; i < 7; ++i) {
        for (int j = i + 1; j < 7; ++j)
            if (p[j] < p[i])
                pp = (uint16_t) (pp + weight[i]);
    }
    *P = pp;
    return 0;
}

static const char face_name[3] = {'R', 'B', 'D'};

int rubik_solve(const char *state, char *out, size_t cap)
{
    uint16_t P, O;
    uint8_t ca = 0, cb = 0;

    if (parse(state, &P, &O, &ca, &cb) < 0)
        return -1;

    int n = solve(P, O, ca, cb);

    size_t need = 1;
    for (int k = 0; k < n; ++k)
        need += (size_t) (1 + (path_turn[k] != 0) + (k > 0));
    if (need > cap) {
        if (cap >= 1)
            out[0] = '\0';
        return -2;
    }

    char *w = out;
    for (int k = 0; k < n; ++k) {
        if (k > 0)
            *w++ = ' ';
        *w++ = face_name[path_face[k]];
        if (path_turn[k] == 1)
            *w++ = '2';
        else if (path_turn[k] == 2)
            *w++ = '\'';
    }
    *w = '\0';
    return n;
}