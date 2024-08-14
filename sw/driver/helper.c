#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/random.h>

#include "helper.h"

int get_random_int(void)
{
	int random;
	get_random_bytes((void*)&random, sizeof(random));
	return random % 6;
}

MODULE_LICENSE("GPL v2");
