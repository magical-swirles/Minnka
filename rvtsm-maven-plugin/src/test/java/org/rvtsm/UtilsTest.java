package org.rvtsm;

import org.junit.Assert;
import org.junit.Test;

import java.io.File;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class UtilsTest {
    @Test
    public void loadMatrixTest() {
        TestUtils tu = new TestUtils();
        File matrixFile = tu.loadFileFromResources("sample-matrix", ".csv");
        String key1 = "com.flowpowered.commons.store.block.impl.AtomicShortIntArrayTest#parallel";
        Set<String> value1 = new HashSet<>(Arrays.asList("e1~10","e372~11", "e1~10", "e369~37", "e370~38", "e372~12",
                "e357~10", "e357~10"));
        String key2 = "com.flowpowered.commons.store.block.impl.AtomicShortIntArrayTest#randomTest";
        Set<String> value2 = new HashSet<>(Arrays.asList("e1~10", "e372~11", "e357~10", "e372~12", "e357~10", "e1~10"));
        String key3 = "com.flowpowered.commons.set.ConcurrentRegularEnumSetTest#testConstructor";

        Map<String, Set<String>> actual = Utils.loadMatrix(matrixFile.getAbsolutePath());

        Assert.assertEquals(20, actual.size());
        Assert.assertEquals(value1, actual.get(key1));
        Assert.assertEquals(value2, actual.get(key2));
        Assert.assertEquals(new HashSet<>(), actual.get(key3));
    }
}
