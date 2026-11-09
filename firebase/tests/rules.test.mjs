import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch,
  collection, getDocs, query, where, Timestamp, serverTimestamp,
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

// O responsável vincula: queima o pedido do filho e cria o aparelho, num lote só.
const approveBatch = (db, { deviceId = CHILD, uid = PARENT, code = CODE, name = 'Celular',
  platform = 'android', label = 'ma***@exemplo.com' } = {}) => {
  const b = writeBatch(db);
  b.update(doc(db, 'pairRequests', code), { used: true, parentUid: uid });
  b.set(doc(db, 'devices', deviceId), {
    parentUid: uid, parentLabel: label, name, platform, pairingCode: code,
    pairedAt: serverTimestamp(), lastSeen: serverTimestamp(),
  });
  return b.commit();
};

const seedRequest = (extra = {}, code = CODE) => seed((db) =>
  setDoc(doc(db, 'pairRequests', code), {
    deviceId: CHILD, name: 'Celular', platform: 'android', expiresAt: minutes(10), used: false, ...extra,
  }));

const seedDevice = (extra = {}) => seed(async (db) => {
  await setDoc(doc(db, 'devices', CHILD), {
    parentUid: PARENT, name: 'Celular', platform: 'android', pairingCode: CODE,
    pairedAt: Timestamp.now(), lastSeen: Timestamp.now(), ...extra,
  });
});

// ---------- pedidos de vínculo (gerados pelo filho) ----------
const request = (extra = {}) => ({
  deviceId: CHILD, name: 'Celular', platform: 'android', expiresAt: minutes(10), used: false, ...extra,
});

test('o aparelho do filho cria um pedido válido', async () => {
  await assertSucceeds(setDoc(doc(childDb(), 'pairRequests', CODE), request()));
});
test('conta de responsável não cria pedido de vínculo', async () => {
  await assertFails(setDoc(doc(parentDb(), 'pairRequests', CODE), request({ deviceId: PARENT })));
});
test('não dá para criar pedido em nome de outro aparelho', async () => {
  await assertFails(setDoc(doc(childDb(), 'pairRequests', CODE), request({ deviceId: CHILD2 })));
});
test('pedido com validade longa demais, já vencido ou usado é recusado', async () => {
  await assertFails(setDoc(doc(childDb(), 'pairRequests', CODE), request({ expiresAt: minutes(120) })));
  await assertFails(setDoc(doc(childDb(), 'pairRequests', CODE), request({ expiresAt: minutes(-1) })));
  await assertFails(setDoc(doc(childDb(), 'pairRequests', CODE), request({ used: true })));
});
test('pedido com nome vazio, enorme, plataforma estranha ou campo extra é recusado', async () => {
  await assertFails(setDoc(doc(childDb(), 'pairRequests', CODE), request({ name: '' })));
  await assertFails(setDoc(doc(childDb(), 'pairRequests', CODE), request({ name: 'x'.repeat(81) })));
  await assertFails(setDoc(doc(childDb(), 'pairRequests', CODE), request({ platform: 'ios' })));
  await assertFails(setDoc(doc(childDb(), 'pairRequests', CODE), request({ parentUid: PARENT })));
});
test('não é possível listar pedidos', async () => {
  await seedRequest();
  await assertFails(getDocs(collection(parentDb(), 'pairRequests')));
  await assertFails(getDocs(collection(childDb(), 'pairRequests')));
});
test('conta logada lê um pedido específico; visitante não', async () => {
  await seedRequest();
  await assertSucceeds(getDoc(doc(parentDb(), 'pairRequests', CODE)));
  await assertSucceeds(getDoc(doc(childDb(), 'pairRequests', CODE)));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'pairRequests', CODE)));
});
test('só o aparelho que gerou o código o cancela', async () => {
  await seedRequest();
  await assertFails(deleteDoc(doc(childDb(CHILD2), 'pairRequests', CODE)));
  await assertFails(deleteDoc(doc(parentDb(), 'pairRequests', CODE)));
  await assertSucceeds(deleteDoc(doc(childDb(), 'pairRequests', CODE)));
});
test('a coleção antiga de códigos do responsável não existe mais', async () => {
  await assertFails(setDoc(doc(parentDb(), 'pairings', CODE),
    { parentUid: PARENT, expiresAt: minutes(10), used: false }));
});

// ---------- vínculo (o responsável aprova) ----------
test('responsável vincula o aparelho com um pedido válido', async () => {
  await seedRequest();
  await assertSucceeds(approveBatch(parentDb()));
});
test('o filho vê o próprio aparelho depois de vinculado', async () => {
  await seedRequest();
  await assertSucceeds(approveBatch(parentDb()));
  await assertSucceeds(getDoc(doc(childDb(), 'devices', CHILD)));
});
test('um responsável vincula vários aparelhos', async () => {
  await seedRequest();
  await seedRequest({ deviceId: CHILD2, name: 'Notebook', platform: 'windows' }, 'ABCD2345');
  await assertSucceeds(approveBatch(parentDb()));
  await assertSucceeds(approveBatch(parentDb(), {
    deviceId: CHILD2, code: 'ABCD2345', name: 'Notebook', platform: 'windows' }));
  const q = query(collection(parentDb(), 'devices'), where('parentUid', '==', PARENT));
  const snap = await assertSucceeds(getDocs(q));
  if (snap.size !== 2) throw new Error('esperava 2 aparelhos');
});
test('o responsável pode trocar o nome ao vincular', async () => {
  await seedRequest();
  await assertSucceeds(approveBatch(parentDb(), { name: 'Celular do Pedro' }));
});
test('criar o aparelho sem queimar o pedido é recusado', async () => {
  await seedRequest();
  await assertFails(setDoc(doc(parentDb(), 'devices', CHILD), {
    parentUid: PARENT, name: 'Celular', platform: 'android', pairingCode: CODE,
    pairedAt: serverTimestamp(), lastSeen: serverTimestamp(),
  }));
});
test('o próprio filho não se vincula a um responsável', async () => {
  await seedRequest();
  const db = childDb();
  const b = writeBatch(db);
  b.update(doc(db, 'pairRequests', CODE), { used: true, parentUid: PARENT });
  b.set(doc(db, 'devices', CHILD), {
    parentUid: PARENT, name: 'Celular', platform: 'android', pairingCode: CODE,
    pairedAt: serverTimestamp(), lastSeen: serverTimestamp(),
  });
  await assertFails(b.commit());
});
test('pedido já usado não vincula de novo', async () => {
  await seedRequest({ used: true, parentUid: OTHER_PARENT });
  await assertFails(approveBatch(parentDb()));
});
test('pedido expirado não vincula', async () => {
  await seedRequest({ expiresAt: Timestamp.fromMillis(Date.now() - 60_000) });
  await assertFails(approveBatch(parentDb()));
});
test('o responsável não vincula em nome de outro responsável', async () => {
  await seedRequest();
  await assertFails(approveBatch(parentDb(), { uid: OTHER_PARENT }));
});
test('o aparelho criado precisa ser o dono do pedido', async () => {
  await seedRequest();
  await assertFails(approveBatch(parentDb(), { deviceId: CHILD2 }));
});
test('a plataforma do aparelho precisa bater com a do pedido', async () => {
  await seedRequest();
  await assertFails(approveBatch(parentDb(), { platform: 'windows' }));
});
test('vincular não sobrescreve um aparelho que já tem dono', async () => {
  await seedRequest();
  await seedDevice({ parentUid: OTHER_PARENT });
  await assertFails(approveBatch(parentDb()));
});
test('pedido não pode ser reaberto depois de usado', async () => {
  await seedRequest();
  await assertSucceeds(approveBatch(parentDb()));
  await assertFails(updateDoc(doc(parentDb(), 'pairRequests', CODE), { used: false }));
  await assertFails(updateDoc(doc(childDb(), 'pairRequests', CODE), { used: false }));
});
test('rótulo do responsável que não é texto ou é enorme é recusado', async () => {
  await seedRequest();
  await assertFails(approveBatch(parentDb(), { label: 42 }));
  await assertFails(approveBatch(parentDb(), { label: 'x'.repeat(81) }));
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
// ---------- tempo de uso ----------
const usageDoc = (db, id = '2026-11-08_com.roblox.client') =>
  doc(db, 'devices', CHILD, 'usage', id);
const usage = (extra = {}) => ({
  day: '2026-11-08', appId: 'com.roblox.client', minutes: 42,
  updatedAt: serverTimestamp(), ...extra,
});

test('aparelho grava o próprio uso; o responsável lê', async () => {
  await seedDevice();
  await assertSucceeds(setDoc(usageDoc(childDb()), usage()));
  await assertSucceeds(getDoc(usageDoc(parentDb())));
  await assertSucceeds(getDocs(query(collection(parentDb(), 'devices', CHILD, 'usage'),
    where('day', '>=', '2026-11-01'))));
});
test('responsável não escreve o uso do filho', async () => {
  await seedDevice();
  await assertFails(setDoc(usageDoc(parentDb()), usage()));
});
test('aparelho não grava uso em outro aparelho', async () => {
  await seedDevice();
  await assertFails(setDoc(usageDoc(childDb(CHILD2)), usage()));
});
test('outro responsável não lê o uso', async () => {
  await seedDevice();
  await seed((db) => setDoc(usageDoc(db), { day: '2026-11-08', appId: 'x', minutes: 1 }));
  await assertFails(getDoc(usageDoc(parentDb(OTHER_PARENT))));
});
test('uso com minutos inválidos ou campos extras é recusado', async () => {
  await seedDevice();
  await assertFails(setDoc(usageDoc(childDb()), usage({ minutes: -1 })));
  await assertFails(setDoc(usageDoc(childDb()), usage({ minutes: 1441 })));
  await assertFails(setDoc(usageDoc(childDb()), usage({ minutes: 1.5 })));
  await assertFails(setDoc(usageDoc(childDb()), usage({ day: '8/11' })));
  await assertFails(setDoc(usageDoc(childDb()), usage({ extra: true })));
});
test('responsável limpa o uso ao desvincular', async () => {
  await seedDevice();
  await seed((db) => setDoc(usageDoc(db), { day: '2026-11-08', appId: 'x', minutes: 1 }));
  await assertSucceeds(deleteDoc(usageDoc(parentDb())));
});

// ---------- avisos de burla e situação das proteções ----------
const alertDoc = (db, id = 'a1') => doc(db, 'devices', CHILD, 'alerts', id);
const alertData = (extra = {}) => ({ kind: 'admin_disabled', at: serverTimestamp(), seen: false, ...extra });
const healthData = (extra = {}) => ({
  usageAccess: true, overlay: true, notifications: true, admin: false,
  monitorRunning: true, checkedAt: serverTimestamp(), ...extra,
});

test('aparelho cria aviso de burla; o responsável lê', async () => {
  await seedDevice();
  await assertSucceeds(setDoc(alertDoc(childDb()), alertData()));
  await assertSucceeds(getDoc(alertDoc(parentDb())));
  await assertSucceeds(getDocs(collection(parentDb(), 'devices', CHILD, 'alerts')));
});
test('aviso com tipo desconhecido, já visto, com data falsa ou campo extra é recusado', async () => {
  await seedDevice();
  await assertFails(setDoc(alertDoc(childDb()), alertData({ kind: 'qualquer' })));
  await assertFails(setDoc(alertDoc(childDb()), alertData({ seen: true })));
  await assertFails(setDoc(alertDoc(childDb()), alertData({ at: minutes(-600) })));
  await assertFails(setDoc(alertDoc(childDb()), alertData({ extra: 1 })));
});
test('aparelho não cria aviso em outro aparelho; responsável não cria aviso', async () => {
  await seedDevice();
  await assertFails(setDoc(alertDoc(childDb(CHILD2)), alertData()));
  await assertFails(setDoc(alertDoc(parentDb()), alertData()));
});
test('aparelho não lê, altera nem apaga avisos; outro responsável também não lê', async () => {
  await seedDevice();
  await seed((db) => setDoc(alertDoc(db), { kind: 'admin_disabled', at: Timestamp.now(), seen: false }));
  await assertFails(getDoc(alertDoc(childDb())));
  await assertFails(updateDoc(alertDoc(childDb()), { seen: true }));
  await assertFails(deleteDoc(alertDoc(childDb())));
  await assertFails(getDoc(alertDoc(parentDb(OTHER_PARENT))));
});
test('responsável marca como visto, mas não altera outros campos', async () => {
  await seedDevice();
  await seed((db) => setDoc(alertDoc(db), { kind: 'admin_disabled', at: Timestamp.now(), seen: false }));
  await assertFails(updateDoc(alertDoc(parentDb()), { kind: 'overlay_revoked' }));
  await assertFails(updateDoc(alertDoc(parentDb()), { seen: false }));
  await assertSucceeds(updateDoc(alertDoc(parentDb()), { seen: true }));
  await assertFails(updateDoc(alertDoc(parentDb(OTHER_PARENT)), { seen: true }));
});
test('responsável apaga avisos ao desvincular', async () => {
  await seedDevice();
  await seed((db) => setDoc(alertDoc(db), { kind: 'admin_disabled', at: Timestamp.now(), seen: false }));
  await assertFails(deleteDoc(alertDoc(parentDb(OTHER_PARENT))));
  await assertSucceeds(deleteDoc(alertDoc(parentDb())));
});
test('aparelho informa a situação das proteções junto com o último contato', async () => {
  await seedDevice();
  await assertSucceeds(updateDoc(doc(childDb(), 'devices', CHILD),
    { lastSeen: serverTimestamp(), health: healthData() }));
});
test('situação das proteções inválida é recusada', async () => {
  await seedDevice();
  const ref = doc(childDb(), 'devices', CHILD);
  await assertFails(updateDoc(ref, { health: healthData({ admin: 'sim' }) }));
  await assertFails(updateDoc(ref, { health: healthData({ extra: true }) }));
  await assertFails(updateDoc(ref, { health: 'tudo certo' }));
  await assertFails(updateDoc(doc(parentDb(), 'devices', CHILD), { health: healthData() }));
});

test('coleções desconhecidas são negadas', async () => {
  await assertFails(setDoc(doc(parentDb(), 'segredos', 'x'), { a: 1 }));
});
