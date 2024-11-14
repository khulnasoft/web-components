#include <gtest/gtest.h>
#include "logger.h"

class TyposearchTestEnvironment : public testing::Environment {
public:
    virtual void SetUp() {

    }

    virtual void TearDown() {

    }
};

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    ::testing::AddGlobalTestEnvironment(new TyposearchTestEnvironment);
    int exitCode = RUN_ALL_TESTS();
    return exitCode;
}
