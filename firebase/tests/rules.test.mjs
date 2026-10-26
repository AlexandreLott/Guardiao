import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch,
  collection, getDocs, Timestamp, serverTimestamp,
} from 'firebase/firestore';

let env;
const PARENT = 'parent-1';
const OTHER_PARENT = 'parent-2';
const CHILD = 'child-1';
const CHILD2 = 'child-2';
const CODE = 'K7M29QXA';

const parentDb = (uid = PARENT) =>
  env.authenticatedContext(uid, { firebase: { sign_in_provider: 'password' } }).firestore();
const childDb = (uid = CHILD) =>
  env.authenticatedContext(uid, { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const minutes = (n) => Timestamp.fromMillis(Date.now() + n * 60_000);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'guardiao-gamer-demo',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

const seed = (fn) => env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));

const claimBatch = (db, { uid = CHILD, parentUid = PARENT, code = CODE } = {}) => {
  const b = writeBatch(db);
  b.update(doc(db, 'pairings', code), { used: true, deviceId: uid });
  b.set(doc(db, 'devices', uid), {
    parentUid, name: 'Celular', platform: 'android', pairingCode: code,
    pairedAt: serverTimestamp(), lastSeen: serverTimestamp(),
  });
  return b.commit();
};

const seedPairing = (extra = {}) => seed((db) =>
  setDoc(doc(db, 'pairings', CODE), { parentUid: PARENT, expiresAt: minutes(10), used: false, ...extra }));

const seedDevice = () => seed(async (db) => {
  await setDoc(doc(db, 'devices', CHILD), {
    parentUid: PARENT, name: 'Celular', platform: 'android', pairingCode: CODE,
    pairedAt: Timestamp.now(), lastSeen: Timestamp.now(),
  });
});

// ---------- pairings ----------
test('responsável cria código válido', async () => {
  await assertSucceeds(setDoc(doc(parentDb(), 'pairings', CODE),
    { parentUid: PARENT, expiresAt: minutes(10), used: false }));
});
test('login anônimo não cria código', async () => {
  await assertFails(setDoc(doc(childDb(), 'pairings', CODE),
    { parentUid: CHILD, expiresAt: minutes(10), used: false }));
});
test('não dá para criar código em nome de outro responsável', async () => {
  await assertFails(setDoc(doc(parentDb(), 'pairings', CODE),
    { parentUid: OTHER_PARENT, expiresAt: minutes(10), used: false }));
});
test('código com validade longa demais é recusado', async () => {
  await assertFails(setDoc(doc(parentDb(), 'pairings', CODE),
    { parentUid: PARENT, expiresAt: minutes(120), used: false }));
});
test('não é possível listar códigos', async () => {
  await seedPairing();
  await assertFails(getDocs(collection(childDb(), 'pairings')));
});
test('aparelho logado lê um código específico', async () => {
  await seedPairing();
  await assertSucceeds(getDoc(doc(childDb(), 'pairings', CODE)));
});
test('visitante sem login não lê nada', async () => {
  await seedPairing();
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'pairings', CODE)));
});

// ---------- vínculo ----------
test('filho vincula o aparelho com um código válido', async () => {
  await seedPairing();
  await assertSucceeds(claimBatch(childDb()));
});
test('criar o aparelho sem queimar o código é recusado', async () => {
  await seedPairing();
  await assertFails(setDoc(doc(childDb(), 'devices', CHILD), {
    parentUid: PARENT, name: 'Celular', platform: 'android', pairingCode: CODE,
    pairedAt: serverTimestamp(), lastSeen: serverTimestamp(),
  }));
});
test('código já usado não vincula outro aparelho', async () => {
  await seedPairing({ used: true, deviceId: CHILD2 });
  await assertFails(claimBatch(childDb()));
});
test('código expirado não vincula', async () => {
  await seedPairing({ expiresAt: Timestamp.fromMillis(Date.now() - 60_000) });
  await assertFails(claimBatch(childDb()));
});
test('aparelho não pode apontar para outro responsável', async () => {
  await seedPairing();
  await assertFails(claimBatch(childDb(), { parentUid: OTHER_PARENT }));
});
test('aparelho não pode se vincular com o uid de outro aparelho', async () => {
  await seedPairing();
  const db = childDb(CHILD);
  const b = writeBatch(db);
  b.update(doc(db, 'pairings', CODE), { used: true, deviceId: CHILD2 });
  b.set(doc(db, 'devices', CHILD2), {
    parentUid: PARENT, name: 'X', platform: 'android', pairingCode: CODE,
    pairedAt: serverTimestamp(), lastSeen: serverTimestamp(),
  });
  await assertFails(b.commit());
});
test('código não pode ser reaberto depois de usado', async () => {
  await seedPairing();
  await assertSucceeds(claimBatch(childDb()));
  await assertFails(updateDoc(doc(childDb(), 'pairings', CODE), { used: false }));
});

// ---------- leitura de dispositivos ----------
test('responsável lê o próprio aparelho; outro responsável não', async () => {
  await seedDevice();
  await assertSucceeds(getDoc(doc(parentDb(), 'devices', CHILD)));
  await assertFails(getDoc(doc(parentDb(OTHER_PARENT), 'devices', CHILD)));
});
test('aparelho lê o próprio documento; outro aparelho não', async () => {
  await seedDevice();
  await assertSucceeds(getDoc(doc(childDb(), 'devices', CHILD)));
  await assertFails(getDoc(doc(childDb(CHILD2), 'devices', CHILD)));
});
test('responsável lista os próprios aparelhos pela consulta por parentUid', async () => {
  await seedDevice();
  const { query, where } = await import('firebase/firestore');
  const q = query(collection(parentDb(), 'devices'), where('parentUid', '==', PARENT));
  const snap = await assertSucceeds(getDocs(q));
  if (snap.size !== 1) throw new Error('esperava 1 aparelho');
});
test('consulta de aparelhos de outro responsável é negada', async () => {
  await seedDevice();
  const { query, where } = await import('firebase/firestore');
  const q = query(collection(parentDb(OTHER_PARENT), 'devices'), where('parentUid', '==', PARENT));
  await assertFails(getDocs(q));
});

// ---------- atualização / remoção ----------
test('aparelho atualiza só o último contato', async () => {
  await seedDevice();
  await assertSucceeds(updateDoc(doc(childDb(), 'devices', CHILD), { lastSeen: serverTimestamp() }));
  await assertFails(updateDoc(doc(childDb(), 'devices', CHILD), { parentUid: OTHER_PARENT }));
});
test('responsável renomeia mas não troca o dono', async () => {
  await seedDevice();
  await assertSucceeds(updateDoc(doc(parentDb(), 'devices', CHILD), { name: 'Tablet' }));
  await assertFails(updateDoc(doc(parentDb(), 'devices', CHILD), { parentUid: OTHER_PARENT }));
});
test('só o responsável dono remove o aparelho', async () => {
  await seedDevice();
  await assertFails(deleteDoc(doc(parentDb(OTHER_PARENT), 'devices', CHILD)));
  await assertFails(deleteDoc(doc(childDb(), 'devices', CHILD)));
  await assertSucceeds(deleteDoc(doc(parentDb(), 'devices', CHILD)));
});

// ---------- apps ----------
test('aparelho grava os próprios apps; o responsável lê', async () => {
  await seedDevice();
  await assertSucceeds(setDoc(doc(childDb(), 'devices', CHILD, 'apps', 'com.roblox.client'),
    { name: 'Roblox', packageName: 'com.roblox.client' }));
  await assertSucceeds(getDoc(doc(parentDb(), 'devices', CHILD, 'apps', 'com.roblox.client')));
  await assertFails(getDoc(doc(parentDb(OTHER_PARENT), 'devices', CHILD, 'apps', 'com.roblox.client')));
});
test('responsável não escreve na lista de apps do aparelho', async () => {
  await seedDevice();
  await assertFails(setDoc(doc(parentDb(), 'devices', CHILD, 'apps', 'x'), { name: 'X' }));
});
test('aparelho não grava apps em outro aparelho', async () => {
  await seedDevice();
  await assertFails(setDoc(doc(childDb(CHILD2), 'devices', CHILD, 'apps', 'x'), { name: 'X' }));
});
test('responsável limpa os apps ao desvincular', async () => {
  await seedDevice();
  await seed((db) => setDoc(doc(db, 'devices', CHILD, 'apps', 'x'), { name: 'X' }));
  await assertSucceeds(deleteDoc(doc(parentDb(), 'devices', CHILD, 'apps', 'x')));
});

// ---------- regras ----------
test('responsável define limite; o filho lê mas não altera', async () => {
  await seedDevice();
  await assertSucceeds(setDoc(doc(parentDb(), 'devices', CHILD, 'rules', 'roblox'),
    { dailyLimitMinutes: 60, blocked: false }));
  await assertSucceeds(getDoc(doc(childDb(), 'devices', CHILD, 'rules', 'roblox')));
  await assertFails(setDoc(doc(childDb(), 'devices', CHILD, 'rules', 'roblox'),
    { dailyLimitMinutes: 600, blocked: false }));
});
test('limite sem tempo definido (null) e bloqueio são aceitos', async () => {
  await seedDevice();
  await assertSucceeds(setDoc(doc(parentDb(), 'devices', CHILD, 'rules', 'roblox'),
    { dailyLimitMinutes: null, blocked: true }));
});
test('limite fora do intervalo é recusado', async () => {
  await seedDevice();
  await assertFails(setDoc(doc(parentDb(), 'devices', CHILD, 'rules', 'a'), { dailyLimitMinutes: 1441, blocked: false }));
  await assertFails(setDoc(doc(parentDb(), 'devices', CHILD, 'rules', 'a'), { dailyLimitMinutes: -5, blocked: false }));
  await assertFails(setDoc(doc(parentDb(), 'devices', CHILD, 'rules', 'a'), { dailyLimitMinutes: 'muito', blocked: false }));
});
test('outro responsável não define regras', async () => {
  await seedDevice();
  await assertFails(setDoc(doc(parentDb(OTHER_PARENT), 'devices', CHILD, 'rules', 'a'), { dailyLimitMinutes: 10, blocked: false }));
});
test('coleções desconhecidas são negadas', async () => {
  await assertFails(setDoc(doc(parentDb(), 'segredos', 'x'), { a: 1 }));
});
