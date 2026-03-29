
void Test_ShowcasePass(FUnitTest& T)
{
	T.AssertTrue(1 + 1 == 2);
	T.AssertEquals(42, 42);
}