#ifndef CCO_LOG_H
#define CCO_LOG_H

#define CCO_LOG_FUNCTION_FAILURE(err) printk(KERN_ERR "cco: %s() failed w/ err=%d\n", __func__, (err))

#endif
